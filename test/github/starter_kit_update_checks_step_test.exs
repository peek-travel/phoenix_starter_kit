defmodule PhoenixStarterKit.Github.StarterKitUpdateChecksStepTest do
  @moduledoc """
  Runs the "Wait for checks, retry fixes on failure" step of
  .github/workflows/starter-kit-update.yml with stub `gh`, `git`, `claude`
  and `sleep` commands. It checks which token reads the CI results, that
  `claude -p` never gets that token, and how the step treats each reply.
  """
  use ExUnit.Case, async: true

  @workflow ".github/workflows/starter-kit-update.yml"
  @step_name "Wait for checks, retry fixes on failure"
  @read_token "read-token-from-github-token"
  @bot_token "bot-token-from-secrets"

  @moduletag :tmp_dir

  # A child repo that removed the workflow has nothing to test here.
  unless File.exists?(@workflow), do: @moduletag(skip: "no #{@workflow} in this repo")

  # Records each call with its GH_TOKEN. Fails with $GH_DENY_ERR when it is
  # set and "$1 $2" matches the $GH_DENY_ON pattern (all calls by default),
  # and with $GH_FIRST_ERR on the first call only. Check runs fail
  # until `claude` made the fix (the "fixed" file), when $FAIL_FIRST is set.
  @gh_stub ~S"""
  #!/usr/bin/env bash
  printf '%s %s\n' "$GH_TOKEN" "$*" >> "$STUB_DIR/gh-calls"
  if [ -n "$GH_DENY_ERR" ] && [[ "$1 $2" == ${GH_DENY_ON:-*} ]]; then echo "$GH_DENY_ERR" >&2; exit 1; fi
  if [ -n "$GH_FIRST_ERR" ] && [ ! -e "$STUB_DIR/first-err-done" ]; then
    touch "$STUB_DIR/first-err-done"; echo "$GH_FIRST_ERR" >&2; exit 1
  fi
  conclusion=success
  [ -n "$FAIL_FIRST" ] && [ ! -e "$STUB_DIR/fixed" ] && conclusion=failure
  case "$1 $2 $*" in
    "api "*check-runs*total_count*) echo 1 ;;
    "api "*check-runs*) echo "[{\"status\":\"completed\",\"conclusion\":\"$conclusion\"}]" ;;
    "api "*"statuses | length"*) echo 0 ;;
    "api "*status*) echo "[]" ;;
    "run list"*) echo 101 ;;
    "run view"*) echo "log of run $3" ;;
  esac
  """

  @git_stub ~S"""
  #!/usr/bin/env bash
  printf '%s %s\n' "$GH_TOKEN" "$*" >> "$STUB_DIR/git-calls"
  [ "$1" = "rev-parse" ] && echo abc123
  exit 0
  """

  # Saves its whole env and its prompt, then "fixes" CI.
  @claude_stub ~S"""
  #!/usr/bin/env bash
  env > "$STUB_DIR/claude-env"
  printf '%s' "$2" > "$STUB_DIR/claude-prompt"
  touch "$STUB_DIR/fixed"
  """

  setup %{tmp_dir: dir} do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    for {name, body} <- [{"gh", @gh_stub}, {"git", @git_stub}, {"claude", @claude_stub}, {"sleep", "#!/bin/sh\n"}] do
      path = Path.join(bin, name)
      File.write!(path, body)
      File.chmod!(path, 0o755)
    end

    script = Path.join(dir, "step.sh")
    File.write!(script, step_script())

    %{dir: dir, bin: bin, script: script}
  end

  describe "the step definition" do
    test "the job gives the built-in token read access only: actions, checks, statuses, contents and PRs" do
      permissions =
        workflow_lines()
        |> Enum.drop_while(&(&1 != "    permissions:"))
        |> Enum.drop(1)
        |> Enum.take_while(&String.starts_with?(&1, "      "))

      assert Enum.sort(permissions) ==
               Enum.sort([
                 "      actions: read",
                 "      checks: read",
                 "      statuses: read",
                 "      contents: read",
                 "      pull-requests: read"
               ])
    end

    test "only this step gets the built-in token, so the job env and the other steps do not" do
      workflow = File.read!(@workflow)

      assert length(String.split(workflow, "secrets.GITHUB_TOKEN")) == 2
      refute workflow =~ "github.token"
      assert "          CHECKS_READ_TOKEN: ${{ secrets.GITHUB_TOKEN }}" in step_lines()
    end

    test "maps the env that these tests set, and the script has no expressions" do
      for line <- [
            "PR: ${{ steps.pr.outputs.number }}",
            "BRANCH: ${{ steps.branch.outputs.name }}",
            "REPO: ${{ github.repository }}"
          ] do
        assert ("          " <> line) in step_lines()
      end

      refute step_script() =~ "${{"
    end

    test "every gh call in the script goes through gh_read" do
      calls =
        step_script()
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.filter(&(&1 =~ ~r/(^|[^_\w])gh /))

      assert calls == [~s(  GH_TOKEN="$READ_TOKEN" gh "$@" 2>"$err")]
    end

    test "no step overrides the bot token, so checkout, the pushes and Mark PR ready use it" do
      assert "        run: gh pr ready \"${{ steps.pr.outputs.number }}\"" in workflow_lines()
      assert "          token: ${{ env.GH_TOKEN }}" in workflow_lines()
      assert workflow_lines() |> Enum.filter(&(&1 =~ "GH_TOKEN: ")) |> length() == 1
      assert "      GH_TOKEN: ${{ secrets.APP_UPDATES_GH_TOKEN || secrets.ACME_CI_GITHUB_TOKEN || secrets.GH_TOKEN }}" in workflow_lines()
    end
  end

  describe "green CI" do
    test "reads every result with the read token and reports passed", ctx do
      {out, 0} = run_step(ctx)

      assert read_output(ctx) == "status=passed\n"
      refute out =~ "::error::"
      assert gh_calls(ctx) != []
      assert Enum.all?(gh_calls(ctx), &String.starts_with?(&1, @read_token <> " api repos/gadabout/acme-wallets-app/commits/abc123/"))
      refute File.exists?(Path.join(ctx.dir, "claude-env"))
    end

    test "retries a rate-limit 403", ctx do
      {out, 0} = run_step(ctx, GH_FIRST_ERR: "gh: API rate limit exceeded for installation ID 1. (HTTP 403)")

      assert read_output(ctx) == "status=passed\n"
      refute out =~ "::error::"
    end
  end

  describe "a refused read" do
    for err <- [
          "gh: Resource not accessible by integration (HTTP 403)",
          "gh: Resource not accessible by personal access token (HTTP 403)",
          "gh: Bad credentials (HTTP 401)"
        ] do
      test "stops the job with a clear error and leaves the PR in draft on #{err}", ctx do
        {out, 1} = run_step(ctx, GH_DENY_ERR: unquote(err))

        assert read_output(ctx) == "status=token_forbidden\n"
        assert out =~ unquote(err)
        assert out =~ "::error::The built-in GITHUB_TOKEN cannot read CI results for abc123"
        assert out =~ "permissions: block"
        refute out =~ "APP_UPDATES_GH_TOKEN"
        assert length(gh_calls(ctx)) == 1
        refute File.exists?(Path.join(ctx.dir, "claude-env"))
      end
    end

    for cmd <- ["run list", "run view"] do
      test "on `gh #{cmd}` stops the job before claude runs", ctx do
        err = "gh: Resource not accessible by integration (HTTP 403)"
        {out, 1} = run_step(ctx, FAIL_FIRST: "1", GH_DENY_ERR: err, GH_DENY_ON: unquote(cmd))

        assert read_output(ctx) == "status=token_forbidden\n"
        assert out =~ "::error::The built-in GITHUB_TOKEN cannot read CI results for abc123"
        refute File.exists?(Path.join(ctx.dir, "claude-env"))
        refute "#{@bot_token} push" in git_calls(ctx)
      end
    end
  end

  describe "failed CI" do
    test "reads the logs with the read token, keeps it from claude and pushes the fix", ctx do
      {_out, 0} = run_step(ctx, FAIL_FIRST: "1")

      assert read_output(ctx) == "status=passed\n"
      assert Enum.all?(gh_calls(ctx), &String.starts_with?(&1, @read_token <> " "))
      assert Enum.any?(gh_calls(ctx), &String.starts_with?(&1, @read_token <> " run list --branch chore/update-1 "))
      assert "#{@read_token} run view 101 --log-failed" in gh_calls(ctx)

      assert File.read!(Path.join(ctx.dir, "claude-prompt")) =~ "<ci_log>\nlog of run 101\n"

      claude_env = File.read!(Path.join(ctx.dir, "claude-env"))
      refute claude_env =~ @read_token
      refute claude_env =~ "CHECKS_READ_TOKEN"

      assert "#{@bot_token} push" in git_calls(ctx)
    end

    test "reports failed after the last fix attempt", ctx do
      {_out, 0} = run_step(ctx, FAIL_FIRST: "1", MAX_FIX_ATTEMPTS: "0")

      assert read_output(ctx) == "status=failed\n"
      refute File.exists?(Path.join(ctx.dir, "claude-env"))
    end
  end

  defp run_step(ctx, overrides \\ []) do
    File.write!(Path.join(ctx.dir, "output"), "")

    env =
      [
        PATH: "#{ctx.bin}:#{System.get_env("PATH")}",
        STUB_DIR: ctx.dir,
        GITHUB_OUTPUT: Path.join(ctx.dir, "output"),
        GH_TOKEN: @bot_token,
        CHECKS_READ_TOKEN: @read_token,
        PR: "7",
        BRANCH: "chore/update-1",
        REPO: "gadabout/acme-wallets-app",
        MAX_FIX_ATTEMPTS: "2",
        CLAUDE_ALLOWED_TOOLS: "Read",
        CLAUDE_MODEL_ARGS: "",
        GH_DENY_ERR: "",
        GH_DENY_ON: "",
        GH_FIRST_ERR: "",
        FAIL_FIRST: ""
      ]
      |> Keyword.merge(overrides)
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)

    System.cmd("bash", ["-e", ctx.script], env: env, stderr_to_stdout: true)
  end

  defp read_output(ctx), do: File.read!(Path.join(ctx.dir, "output"))

  defp gh_calls(ctx), do: calls(ctx, "gh-calls")

  defp git_calls(ctx), do: calls(ctx, "git-calls")

  defp calls(ctx, file) do
    case File.read(Path.join(ctx.dir, file)) do
      {:ok, text} -> String.split(text, "\n", trim: true)
      {:error, :enoent} -> []
    end
  end

  defp workflow_lines, do: @workflow |> File.read!() |> String.split("\n")

  defp step_lines do
    workflow_lines()
    |> Enum.drop_while(&(&1 != "      - name: #{@step_name}"))
    |> case do
      [first | rest] -> [first | Enum.take_while(rest, &(not String.starts_with?(&1, "      - name: ")))]
      [] -> flunk("no step named #{inspect(@step_name)} in #{@workflow}")
    end
  end

  # The `run: |` block, without its 10-space YAML indent.
  defp step_script do
    step_lines()
    |> Enum.drop_while(&(&1 != "        run: |"))
    |> Enum.drop(1)
    |> Enum.take_while(&(&1 == "" or String.starts_with?(&1, "          ")))
    |> Enum.map_join("\n", &String.replace_prefix(&1, "          ", ""))
  end
end
