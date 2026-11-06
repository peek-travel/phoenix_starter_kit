defmodule PhoenixStarterKit.Github.StarterKitUpdateChecksStepTest do
  @moduledoc """
  Runs the CI-fix steps of .github/workflows/starter-kit-update.yml ("Wait
  for checks", "Fix CI" and "Push fix") with stub `gh`, `git`, `claude` and
  `sleep` commands. It checks which token each step uses, that `claude -p`
  gets no GitHub token, and how each step treats each reply.
  """
  use ExUnit.Case, async: true

  @workflow ".github/workflows/starter-kit-update.yml"
  @wait_step "Wait for checks"
  @fix_step "Fix CI (attempt 1)"
  @push_step "Push fix (attempt 1)"
  @read_token "read-token-from-github-token"
  @bot_token "bot-token-from-secrets"
  @claude_key "sk-ant-api03-claude-key-for-the-tests"

  @moduletag :tmp_dir

  # A child repo that removed the workflow has nothing to test here.
  unless File.exists?(@workflow), do: @moduletag(skip: "no #{@workflow} in this repo")

  # Records each call with its GH_TOKEN. Fails with $GH_DENY_ERR when it is
  # set and "$1 $2" matches the $GH_DENY_ON pattern (all calls by default),
  # and with $GH_FIRST_ERR on the first call only. Check runs fail when
  # $FAIL is set. No check registers when $NO_CHECKS is set.
  @gh_stub ~S"""
  #!/usr/bin/env bash
  printf '%s %s\n' "$GH_TOKEN" "$*" >> "$STUB_DIR/gh-calls"
  if [ -n "$GH_DENY_ERR" ] && [[ "$1 $2" == ${GH_DENY_ON:-*} ]]; then echo "$GH_DENY_ERR" >&2; exit 1; fi
  if [ -n "$GH_FIRST_ERR" ] && [ ! -e "$STUB_DIR/first-err-done" ]; then
    touch "$STUB_DIR/first-err-done"; echo "$GH_FIRST_ERR" >&2; exit 1
  fi
  conclusion=success
  [ -n "$FAIL" ] && conclusion=failure
  case "$1 $2 $*" in
    "api "*check-runs*total_count*) if [ -n "$NO_CHECKS" ]; then echo 0; else echo 1; fi ;;
    "api "*check-runs*) echo "[{\"status\":\"completed\",\"conclusion\":\"$conclusion\"}]" ;;
    "api "*"statuses | length"*) echo 0 ;;
    "api "*status*) echo "[]" ;;
    "run list"*)
      if [ -n "$NO_RUNS" ]; then echo "[]"; else
        echo '[{"databaseId":101,"conclusion":"failure","headSha":"abc123"},{"databaseId":102,"conclusion":"failure","headSha":"older"},{"databaseId":103,"conclusion":"success","headSha":"abc123"}]'
      fi ;;
    "run view"*) echo "log of run $3" ;;
  esac
  """

  # Records each call with the git config that the env gives it. HEAD is
  # def456 after `claude` made a commit (the "fixed" file), else abc123.
  # `diff` prints $WORKFLOW_DIFF. `push` fails when $PUSH_FAIL is set.
  @git_stub ~S"""
  #!/usr/bin/env bash
  printf '%s\n' "$*" >> "$STUB_DIR/git-calls"
  env | grep -E '^GIT_CONFIG_(COUNT|GLOBAL|NOSYSTEM|KEY|VALUE)' | sort > "$STUB_DIR/git-env"
  if [ "$1" = "rev-parse" ]; then
    if [ -e "$STUB_DIR/fixed" ]; then echo def456; else echo abc123; fi
  fi
  if [ "$1" = "diff" ]; then printf '%s' "$WORKFLOW_DIFF"; fi
  if [ "$1" = "push" ] && [ -n "$PUSH_FAIL" ]; then exit 1; fi
  exit 0
  """

  # Saves its whole env and its prompt, writes to the runner's file-command
  # files, then "fixes" CI and commits, except when $NO_COMMIT is set.
  # Exits with $CLAUDE_RC.
  @claude_stub ~S"""
  #!/usr/bin/env bash
  env > "$STUB_DIR/claude-env"
  printf '%s' "$2" > "$STUB_DIR/claude-prompt"
  echo "BASH_ENV=/tmp/x" >> "$STUB_DIR/github-env"
  echo "/tmp/x" >> "$STUB_DIR/github-path"
  echo "committed=true" >> "$STUB_DIR/output"
  [ -n "$NO_COMMIT" ] || touch "$STUB_DIR/fixed"
  exit "${CLAUDE_RC:-0}"
  """

  setup %{tmp_dir: dir} do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    for {name, body} <- [{"gh", @gh_stub}, {"git", @git_stub}, {"claude", @claude_stub}, {"sleep", "#!/bin/sh\n"}] do
      path = Path.join(bin, name)
      File.write!(path, body)
      File.chmod!(path, 0o755)
    end

    for file <- ["output", "github-env", "github-path"], do: File.write!(Path.join(dir, file), "")

    %{dir: dir, bin: bin}
  end

  describe "the step definitions" do
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

    test "only the 3 wait steps get the built-in token" do
      workflow = File.read!(@workflow)

      assert length(String.split(workflow, "secrets.GITHUB_TOKEN")) == 4
      refute workflow =~ "github.token"

      for name <- [@wait_step, "Wait for checks (after fix 1)", "Wait for checks (after fix 2)"] do
        assert "          CHECKS_READ_TOKEN: ${{ secrets.GITHUB_TOKEN }}" in step_lines(name)
      end
    end

    test "the repeated steps run the same script as the first one" do
      assert "        run: &wait_for_checks |" in step_lines(@wait_step)
      assert "        run: &fix_ci |" in step_lines(@fix_step)
      assert "        run: &push_fix |" in step_lines(@push_step)

      for {name, alias_line} <- [
            {"Wait for checks (after fix 1)", "        run: *wait_for_checks"},
            {"Wait for checks (after fix 2)", "        run: *wait_for_checks"},
            {"Fix CI (attempt 2)", "        run: *fix_ci"},
            {"Push fix (attempt 2)", "        run: *push_fix"}
          ] do
        assert alias_line in step_lines(name)
      end
    end

    test "each step runs after the one before, and its env has the attempt and the outputs it reads" do
      chain = [
        {@wait_step, "steps.pr.outputs.had_changes == 'true'", "0"},
        {@fix_step, "steps.wait_0.outputs.status == 'fix'", "1"},
        {@push_step, "steps.fix_1.outputs.committed == 'true'", "1"},
        {"Wait for checks (after fix 1)", "steps.push_1.outputs.pushed == 'true'", "1"},
        {"Fix CI (attempt 2)", "steps.wait_1.outputs.status == 'fix'", "2"},
        {"Push fix (attempt 2)", "steps.fix_2.outputs.committed == 'true'", "2"},
        {"Wait for checks (after fix 2)", "steps.push_2.outputs.pushed == 'true'", "2"}
      ]

      for {name, condition, attempt} <- chain do
        assert "        if: #{condition}" in step_lines(name)
        assert "          ATTEMPT: #{attempt}" in step_lines(name)
      end

      for {name, wait} <- [{@fix_step, "wait_0"}, {"Fix CI (attempt 2)", "wait_1"}] do
        assert "          CURRENT_SHA: ${{ steps.#{wait}.outputs.sha }}" in step_lines(name)
        assert "          LOG_FILE: ${{ steps.#{wait}.outputs.log }}" in step_lines(name)
      end

      for {name, wait} <- [{@push_step, "wait_0"}, {"Push fix (attempt 2)", "wait_1"}] do
        assert "          CURRENT_SHA: ${{ steps.#{wait}.outputs.sha }}" in step_lines(name)
      end

      assert "          LAST_STATUS: ${{ steps.wait_2.outputs.status || steps.wait_1.outputs.status || steps.wait_0.outputs.status }}" in step_lines(
               "CI result"
             )
    end

    test "maps the env that these tests set, and the scripts have no expressions" do
      for line <- ["PR: ${{ steps.pr.outputs.number }}", "BRANCH: ${{ steps.branch.outputs.name }}", "REPO: ${{ github.repository }}"] do
        assert ("          " <> line) in step_lines(@wait_step)
      end

      for line <- [
            "BRANCH: ${{ steps.branch.outputs.name }}",
            "REPO: ${{ github.repository }}",
            "GIT_CONFIG_SHA: ${{ steps.git_state.outputs.config_sha }}"
          ] do
        assert ("          " <> line) in step_lines(@push_step)
        assert ("          " <> line) in step_lines("Push fix (attempt 2)")
      end

      for name <- [@wait_step, @fix_step, @push_step], do: refute(step_script(name) =~ "${{")
    end

    test "every gh call in the wait script goes through gh_read" do
      calls =
        step_script(@wait_step)
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.filter(&(&1 =~ ~r/(^|[^_\w])gh /))

      assert calls == [~s(  GH_TOKEN="$READ_TOKEN" gh "$@" 2>"$err")]
    end

    test "the wait and fix scripts never push, and the push script never runs claude" do
      refute step_script(@wait_step) =~ "git push"
      refute step_script(@fix_step) =~ "git push"
      refute step_script(@push_step) =~ "claude"
    end
  end

  describe "wait: green CI" do
    test "reads every result with the read token and reports passed", ctx do
      {out, 0} = run_wait(ctx)

      assert read_output(ctx) == "status=passed\nsha=abc123\nlog=\n"
      refute out =~ "::error::"
      assert gh_calls(ctx) != []
      assert Enum.all?(gh_calls(ctx), &String.starts_with?(&1, @read_token <> " api repos/gadabout/acme-wallets-app/commits/abc123/"))
    end

    test "retries a rate-limit 403", ctx do
      {out, 0} = run_wait(ctx, GH_FIRST_ERR: "gh: API rate limit exceeded for installation ID 1. (HTTP 403)")

      assert read_output(ctx) =~ "status=passed\n"
      refute out =~ "::error::"
    end
  end

  describe "wait: a refused read" do
    for err <- [
          "gh: Resource not accessible by integration (HTTP 403)",
          "gh: Resource not accessible by personal access token (HTTP 403)",
          "gh: Bad credentials (HTTP 401)"
        ] do
      test "stops the job with a clear error and leaves the PR in draft on #{err}", ctx do
        {out, 1} = run_wait(ctx, GH_DENY_ERR: unquote(err))

        assert read_output(ctx) =~ "status=token_forbidden\n"
        assert out =~ unquote(err)
        assert out =~ "::error::The built-in GITHUB_TOKEN cannot read CI results for abc123"
        assert out =~ "permissions: block"
        refute out =~ "APP_UPDATES_GH_TOKEN"
        assert length(gh_calls(ctx)) == 1
      end
    end

    for cmd <- ["run list", "run view"] do
      test "on `gh #{cmd}` stops the job with no fix attempt", ctx do
        err = "gh: Resource not accessible by integration (HTTP 403)"
        {out, 1} = run_wait(ctx, FAIL: "1", GH_DENY_ERR: err, GH_DENY_ON: unquote(cmd))

        assert read_output(ctx) =~ "status=token_forbidden\n"
        assert out =~ "::error::The built-in GITHUB_TOKEN cannot read CI results for abc123"
      end
    end
  end

  describe "wait: failed CI" do
    test "reads the failing runs' logs with the read token into a new file and asks for a fix", ctx do
      {out, 0} = run_wait(ctx, FAIL: "1")

      assert %{"status" => "fix", "sha" => "abc123", "log" => log} = outputs(ctx)
      assert out =~ "Fix attempt 1 of 2 is next."
      assert String.starts_with?(log, Path.join(ctx.dir, "ci-failure-log."))
      assert File.read!(log) == "log of run 101\n"

      assert Enum.all?(gh_calls(ctx), &String.starts_with?(&1, @read_token <> " "))

      assert "#{@read_token} run list --repo gadabout/acme-wallets-app --branch chore/update-1 --limit 100 --json databaseId,conclusion,headSha" in gh_calls(
               ctx
             )

      assert "#{@read_token} run view 101 --repo gadabout/acme-wallets-app --log-failed" in gh_calls(ctx)
      refute Enum.any?(gh_calls(ctx), &(&1 =~ "run view 102"))
      refute Enum.any?(gh_calls(ctx), &(&1 =~ "run view 103"))
    end

    test "reports failed when no failure log exists, so claude does not guess", ctx do
      {out, 0} = run_wait(ctx, FAIL: "1", NO_RUNS: "1")

      assert outputs(ctx)["status"] == "failed"
      assert out =~ "::error::Checks failed on abc123 but no failure log could be retrieved"
    end

    test "reports failed after the last fix attempt, without reading logs", ctx do
      {_out, 0} = run_wait(ctx, FAIL: "1", ATTEMPT: "2")

      assert outputs(ctx)["status"] == "failed"
      refute Enum.any?(gh_calls(ctx), &(&1 =~ " run "))
    end

    test "reports failed when MAX_FIX_ATTEMPTS is 0", ctx do
      {_out, 0} = run_wait(ctx, FAIL: "1", MAX_FIX_ATTEMPTS: "0")

      assert outputs(ctx)["status"] == "failed"
    end

    test "uses at most 2 fix attempts, because the job has 2 fix rounds", ctx do
      {out, 0} = run_wait(ctx, FAIL: "1", ATTEMPT: "2", MAX_FIX_ATTEMPTS: "5")

      assert out =~ "::warning::MAX_FIX_ATTEMPTS is 5, but this job has only 2 fix rounds. It uses 2."
      assert outputs(ctx)["status"] == "failed"
    end
  end

  describe "wait: no checks register" do
    test "names the bot push on the first wait", ctx do
      {out, 0} = run_wait(ctx, NO_CHECKS: "1")

      assert outputs(ctx)["status"] == "failed"
      assert out =~ "::error::No check runs registered for abc123 — CI did not trigger on the bot push."
    end

    test "names the fix push after a fix", ctx do
      {out, 0} = run_wait(ctx, NO_CHECKS: "1", ATTEMPT: "1")

      assert out =~ "CI did not trigger on the fix-attempt push."
    end
  end

  describe "fix" do
    setup ctx do
      log = Path.join(ctx.dir, "ci-failure-log.test")
      File.write!(log, "log of run 101\n")
      %{log: log}
    end

    test "gives claude the log and the Claude key, and no GitHub token or runner files", ctx do
      {_out, 0} = run_fix(ctx)

      assert File.read!(Path.join(ctx.dir, "claude-prompt")) =~ "<ci_log>\nlog of run 101\n"

      claude_env = env_map(File.read!(Path.join(ctx.dir, "claude-env")))
      assert claude_env["ANTHROPIC_API_KEY"] == @claude_key
      refute Map.has_key?(claude_env, "CLAUDE_CODE_OAUTH_TOKEN"), "claude got CLAUDE_CODE_OAUTH_TOKEN"

      for name <- ["CLAUDE_AUTH_VALUE", "GH_TOKEN", "CHECKS_READ_TOKEN", "SLACK_WEBHOOK_URL", "GITHUB_OUTPUT", "GITHUB_ENV", "GITHUB_PATH"] do
        refute Map.has_key?(claude_env, name), "claude got #{name}"
      end

      assert read_output(ctx) == "committed=true\n"
    end

    test "sets the OAuth variable for an OAuth token, trimmed", ctx do
      {_out, 0} = run_fix(ctx, CLAUDE_AUTH_VALUE: " sk-ant-oat01-oauth-token-for-the-tests\n")

      claude_env = env_map(File.read!(Path.join(ctx.dir, "claude-env")))
      assert claude_env["CLAUDE_CODE_OAUTH_TOKEN"] == "sk-ant-oat01-oauth-token-for-the-tests"
      refute Map.has_key?(claude_env, "ANTHROPIC_API_KEY"), "claude got ANTHROPIC_API_KEY"
    end

    test "empties what claude wrote to the runner's env, path and output files", ctx do
      {_out, 0} = run_fix(ctx, NO_COMMIT: "1")

      assert File.read!(Path.join(ctx.dir, "github-env")) == ""
      assert File.read!(Path.join(ctx.dir, "github-path")) == ""
      assert read_output(ctx) == "committed=false\n"
    end

    test "reports no commit when the fix made none, because nothing new can be tested", ctx do
      {out, 0} = run_fix(ctx, NO_COMMIT: "1")

      assert out =~ "::error::Fix attempt 1 made no commit"
      assert read_output(ctx) == "committed=false\n"
    end

    test "still reports the result when claude fails", ctx do
      {_out, 0} = run_fix(ctx, CLAUDE_RC: "1")

      assert read_output(ctx) == "committed=true\n"
    end

    test "never pushes", ctx do
      {_out, 0} = run_fix(ctx)

      refute Enum.any?(git_calls(ctx), &String.starts_with?(&1, "push"))
    end
  end

  describe "push" do
    setup ctx do
      File.mkdir_p!(Path.join([ctx.dir, "repo", ".git", "hooks"]))
      :ok
    end

    test "pushes HEAD to the branch with the token in a masked header, not on the command line", ctx do
      {out, 0} = run_push(ctx)

      header = "AUTHORIZATION: basic " <> Base.encode64("x-access-token:" <> @bot_token)
      assert out =~ "::add-mask::#{header}"

      assert git_calls(ctx) == [
               "diff --name-only abc123 HEAD -- .github/workflows",
               "push --no-verify https://github.com/gadabout/acme-wallets-app.git HEAD:refs/heads/chore/update-1"
             ]

      refute Enum.any?(git_calls(ctx), &(&1 =~ @bot_token))

      assert File.read!(Path.join(ctx.dir, "git-env")) ==
               """
               GIT_CONFIG_COUNT=2
               GIT_CONFIG_GLOBAL=/dev/null
               GIT_CONFIG_KEY_0=core.hooksPath
               GIT_CONFIG_KEY_1=http.https://github.com/.extraheader
               GIT_CONFIG_NOSYSTEM=1
               GIT_CONFIG_VALUE_0=/dev/null
               GIT_CONFIG_VALUE_1=#{header}
               """

      assert read_output(ctx) == "pushed=true\n"
    end

    test "reports a failed push", ctx do
      {out, 0} = run_push(ctx, PUSH_FAIL: "1")

      assert out =~ "::error::git push failed after fix attempt 1"
      assert read_output(ctx) == "pushed=false\n"
    end

    test "does not push a fix that changes a workflow file", ctx do
      {out, 0} = run_push(ctx, WORKFLOW_DIFF: ".github/workflows/elixir.yml\n")

      assert out =~ "::error::Fix attempt 1 changed a file in .github/workflows. The job does not push it."
      refute Enum.any?(git_calls(ctx), &String.starts_with?(&1, "push"))
      assert read_output(ctx) == "pushed=false\n"
    end

    test "stops before git runs when .git/config changed", ctx do
      {out, 1} = run_push(ctx, GIT_CONFIG_SHA: "another-sha")

      assert out =~ "::error::.git/config or .git/hooks changed after the Claude steps started."
      assert git_calls(ctx) == []
      refute out =~ @bot_token
    end

    test "stops before git runs when .git/hooks has a hook", ctx do
      File.write!(Path.join([ctx.dir, "repo", ".git", "hooks", "pre-push"]), "#!/bin/sh\n")
      {out, 1} = run_push(ctx)

      assert out =~ "::error::.git/config or .git/hooks changed after the Claude steps started."
      assert git_calls(ctx) == []
    end

    test "accepts the sample hooks that git makes", ctx do
      File.write!(Path.join([ctx.dir, "repo", ".git", "hooks", "pre-push.sample"]), "#!/bin/sh\n")

      {_out, 0} = run_push(ctx)
      assert read_output(ctx) == "pushed=true\n"
    end
  end

  defp run_wait(ctx, overrides \\ []) do
    run(ctx, @wait_step, [CHECKS_READ_TOKEN: @read_token, PR: "7", ATTEMPT: "0", MAX_FIX_ATTEMPTS: "2", RUNNER_TEMP: ctx.dir], overrides)
  end

  defp run_fix(ctx, overrides) do
    env = [
      CLAUDE_AUTH_VALUE: @claude_key,
      PR: "7",
      CURRENT_SHA: "abc123",
      LOG_FILE: ctx.log,
      ATTEMPT: "1",
      CLAUDE_ALLOWED_TOOLS: "Read",
      CLAUDE_MODEL_ARGS: ""
    ]

    run(ctx, @fix_step, env, overrides)
  end

  defp run_fix(ctx), do: run_fix(ctx, [])

  # Runs in the "repo" folder, with a .git/config.
  defp run_push(ctx, overrides \\ []) do
    repo = Path.join(ctx.dir, "repo")
    config = Path.join([repo, ".git", "config"])
    unless File.exists?(config), do: File.write!(config, "[core]\n\tbare = false\n")
    sha = :sha256 |> :crypto.hash(File.read!(config)) |> Base.encode16(case: :lower)

    env = [GH_TOKEN: @bot_token, GIT_CONFIG_SHA: sha, CURRENT_SHA: "abc123", ATTEMPT: "1", WORKFLOW_DIFF: ""]
    run(ctx, @push_step, env, overrides, cd: repo)
  end

  # Runs the step's script the way GitHub does (`bash -e`), with the env
  # the test gives it and the runner's file-command files. It unsets the
  # tokens and keys that the env of the test run can have.
  defp run(ctx, step, env, overrides, opts \\ []) do
    script = Path.join(ctx.dir, "step.sh")
    File.write!(script, step_script(step))

    env =
      [
        PATH: "#{ctx.bin}:#{System.get_env("PATH")}",
        STUB_DIR: ctx.dir,
        GITHUB_OUTPUT: Path.join(ctx.dir, "output"),
        GITHUB_ENV: Path.join(ctx.dir, "github-env"),
        GITHUB_PATH: Path.join(ctx.dir, "github-path"),
        BRANCH: "chore/update-1",
        REPO: "gadabout/acme-wallets-app",
        GH_TOKEN: nil,
        CHECKS_READ_TOKEN: nil,
        SLACK_WEBHOOK_URL: nil,
        ANTHROPIC_API_KEY: nil,
        CLAUDE_CODE_OAUTH_TOKEN: nil,
        GH_DENY_ERR: "",
        GH_DENY_ON: "",
        GH_FIRST_ERR: "",
        FAIL: "",
        NO_CHECKS: "",
        NO_RUNS: "",
        NO_COMMIT: "",
        PUSH_FAIL: "",
        CLAUDE_RC: "0"
      ]
      |> Keyword.merge(env)
      |> Keyword.merge(overrides)
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)

    System.cmd("bash", ["-e", script], [env: env, stderr_to_stdout: true] ++ opts)
  end

  defp read_output(ctx), do: File.read!(Path.join(ctx.dir, "output"))

  defp outputs(ctx) do
    ctx
    |> read_output()
    |> String.split("\n", trim: true)
    |> Map.new(fn line -> line |> String.split("=", parts: 2) |> List.to_tuple() end)
  end

  defp env_map(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.contains?(&1, "="))
    |> Map.new(fn line -> line |> String.split("=", parts: 2) |> List.to_tuple() end)
  end

  defp gh_calls(ctx), do: calls(ctx, "gh-calls")

  defp git_calls(ctx), do: calls(ctx, "git-calls")

  defp calls(ctx, file) do
    case File.read(Path.join(ctx.dir, file)) do
      {:ok, text} -> String.split(text, "\n", trim: true)
      {:error, :enoent} -> []
    end
  end

  defp workflow_lines, do: @workflow |> File.read!() |> String.split("\n")

  defp step_lines(name) do
    workflow_lines()
    |> Enum.drop_while(&(&1 != "      - name: #{name}"))
    |> case do
      [first | rest] -> [first | Enum.take_while(rest, &(not String.starts_with?(&1, "      - ")))]
      [] -> flunk("no step named #{inspect(name)} in #{@workflow}")
    end
  end

  # The `run: |` block (with or without a YAML anchor), without its 10-space
  # YAML indent.
  defp step_script(name) do
    step_lines(name)
    |> Enum.drop_while(&(not (&1 =~ ~r/^        run: (&\w+ )?\|$/)))
    |> Enum.drop(1)
    |> Enum.take_while(&(&1 == "" or String.starts_with?(&1, "          ")))
    |> Enum.map_join("\n", &String.replace_prefix(&1, "          ", ""))
  end
end
