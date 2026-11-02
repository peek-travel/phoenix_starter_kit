defmodule PhoenixStarterKit.Github.StarterKitUpdateJiraStepTest do
  @moduledoc """
  Runs the "Create Jira ticket (gadabout)" step of
  .github/workflows/starter-kit-update.yml with stub `curl` and `gh`
  commands, so each Jira reply is tested without a network call.
  """
  use ExUnit.Case, async: true

  @workflow ".github/workflows/starter-kit-update.yml"
  @step_name "Create Jira ticket (gadabout)"
  @token "c2VjcmV0LXVzZXI6c2VjcmV0LXRva2Vu"
  @pr_url "https://github.com/gadabout/acme-wallets-app/pull/7"

  @moduletag :tmp_dir

  # A child repo that removed the workflow has nothing to test here.
  unless File.exists?(@workflow), do: @moduletag(skip: "no #{@workflow} in this repo")

  # Records its arguments and the files it was given, then replies with
  # $CURL_CODE / $CURL_BODY (no body when $NO_BODY is set) and exits with
  # $CURL_RC.
  @curl_stub ~S"""
  #!/usr/bin/env bash
  printf '%s\n' "$@" > "$STUB_DIR/curl-args"
  out=""; data=""; header=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -o) out=$2; shift ;;
      --data-binary) data=${2#@}; shift ;;
      -H) case "$2" in @*) header=${2#@} ;; esac; shift ;;
    esac
    shift
  done
  cp "$data" "$STUB_DIR/payload.json"
  cp "$header" "$STUB_DIR/auth-header"
  [ -n "$(find "$header" -perm 0600)" ] && touch "$STUB_DIR/auth-header-is-0600"
  [ -z "$NO_BODY" ] && printf '%s' "$CURL_BODY" > "$out"
  printf '%s' "$CURL_CODE"
  exit "${CURL_RC:-0}"
  """

  # Records each call; a title PATCH exits with $GH_RC.
  @gh_stub ~S"""
  #!/usr/bin/env bash
  printf '%s\n' "$*" >> "$STUB_DIR/gh-calls"
  [ "$1 $2 $3" = "api -X PATCH" ] && exit "${GH_RC:-0}"
  exit 0
  """

  setup %{tmp_dir: dir} do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    for {name, body} <- [{"curl", @curl_stub}, {"gh", @gh_stub}] do
      path = Path.join(bin, name)
      File.write!(path, body)
      File.chmod!(path, 0o755)
    end

    script = Path.join(dir, "step.sh")
    File.write!(script, step_script())

    summary = Path.join(dir, "summary.md")
    File.write!(summary, "# Backport\n- $(touch #{dir}/pwned) `x`\n")

    %{dir: dir, bin: bin, script: script, summary: summary}
  end

  describe "the step definition" do
    test "runs only in gadabout repos with changes, after the PR step and before Wait for checks" do
      lines = workflow_lines()
      names = Enum.filter(lines, &String.starts_with?(&1, "      - name: "))
      index = Enum.find_index(names, &(&1 == "      - name: #{@step_name}"))
      assert index, "no step named #{inspect(@step_name)} in #{@workflow}"

      assert Enum.at(names, index - 1) == "      - name: Push branch and open draft PR"
      assert Enum.at(names, index + 1) == "      - name: Wait for checks, retry fixes on failure"

      assert "        if: github.repository_owner == 'gadabout' && steps.pr.outputs.had_changes == 'true'" in step_lines()
    end

    test "only this step gets the Jira secrets" do
      workflow = File.read!(@workflow)
      step = Enum.join(step_lines(), "\n")

      assert step =~ "JIRA_BASE64: ${{ secrets.ACME_JIRA_SCOPED_TOKEN_WRITE_BASE64 }}"
      assert step =~ "JIRA_CLOUD_ID: ${{ secrets.ACME_JIRA_SCOPED_TOKEN_WRITE_CLOUDID }}"

      assert length(String.split(workflow, "secrets.ACME_JIRA_SCOPED_TOKEN_WRITE_BASE64")) == 2
      assert length(String.split(workflow, "secrets.ACME_JIRA_SCOPED_TOKEN_WRITE_CLOUDID")) == 2
    end

    test "maps the env that these tests set, and the script has no expressions" do
      step = Enum.join(step_lines(), "\n")

      for line <- [
            "PR_URL: ${{ steps.pr.outputs.url }}",
            "PR_TITLE: ${{ steps.pr.outputs.title }}",
            "PR_NUMBER: ${{ steps.pr.outputs.number }}",
            "REPO: ${{ github.repository }}",
            "REPO_NAME: ${{ github.event.repository.name }}",
            "SUMMARY_FILE: /tmp/starter-kit-update-summary.md"
          ] do
        assert step =~ "          " <> line
      end

      refute step_script() =~ "${{"
    end
  end

  describe "missing secrets" do
    test "warns, makes no ticket and lets the job go on when the token is empty", ctx do
      {out, 0} = run_step(ctx, JIRA_BASE64: "")

      assert out =~ "::warning::ACME_JIRA_SCOPED_TOKEN_WRITE_BASE64 or ACME_JIRA_SCOPED_TOKEN_WRITE_CLOUDID is not set"
      refute out =~ "::error::"
      refute File.exists?(Path.join(ctx.dir, "curl-args"))
      refute File.exists?(Path.join(ctx.dir, "gh-calls"))
      assert File.read!(Path.join(ctx.dir, "output")) == ""
    end

    test "warns and lets the job go on when the cloud id is empty", ctx do
      {out, 0} = run_step(ctx, JIRA_CLOUD_ID: "")

      assert out =~ "::warning::"
      refute File.exists?(Path.join(ctx.dir, "curl-args"))
    end
  end

  describe "a created ticket" do
    test "sends only project, type, summary and description, and puts the key in the title", ctx do
      {out, 0} = run_step(ctx)

      assert out =~ "Created Jira ticket DEV-4242"
      assert File.read!(Path.join(ctx.dir, "output")) == "key=DEV-4242\n"

      fields = ctx.dir |> Path.join("payload.json") |> File.read!() |> Jason.decode!() |> Map.fetch!("fields")

      assert Map.keys(fields) |> Enum.sort() == ["description", "issuetype", "project", "summary"]
      assert fields["project"] == %{"key" => "DEV"}
      assert fields["issuetype"] == %{"name" => "Technical Task"}
      assert fields["summary"] == "acme-wallets-app: chore: backport phoenix_starter_kit updates"

      [code_block, link] = fields["description"]["content"]
      assert [%{"text" => text}] = code_block["content"]
      assert text == File.read!(ctx.summary)
      assert Enum.any?(link["content"], &(&1["text"] == @pr_url))

      assert gh_calls(ctx) == [
               "api -X PATCH repos/gadabout/acme-wallets-app/pulls/7 -f title=chore: DEV-4242 - backport phoenix_starter_kit updates --silent"
             ]
    end

    test "treats the summary file as data", ctx do
      {_out, 0} = run_step(ctx)

      refute File.exists?(Path.join(ctx.dir, "pwned"))
    end

    test "puts the key first when the title has no type", ctx do
      {_out, 0} = run_step(ctx, PR_TITLE: "Update things")

      assert gh_calls(ctx) == ["api -X PATCH repos/gadabout/acme-wallets-app/pulls/7 -f title=DEV-4242 Update things --silent"]
    end

    test "uses a fixed text instead of a symlinked summary file", ctx do
      secret = Path.join(ctx.dir, "secret")
      File.write!(secret, "do not send")
      link = Path.join(ctx.dir, "link.md")
      File.ln_s!(secret, link)

      {_out, 0} = run_step(ctx, SUMMARY_FILE: link)

      refute File.read!(Path.join(ctx.dir, "payload.json")) =~ "do not send"
      assert File.read!(Path.join(ctx.dir, "payload.json")) =~ "No summary file was written."
    end

    test "cuts a long summary to 20000 characters", ctx do
      File.write!(ctx.summary, String.duplicate("a", 40_000))

      {_out, 0} = run_step(ctx)

      payload = ctx.dir |> Path.join("payload.json") |> File.read!() |> Jason.decode!()
      [code_block, _link] = payload["fields"]["description"]["content"]
      assert [%{"text" => text}] = code_block["content"]
      assert String.length(text) == 20_000
    end

    test "fails with a clear error when the title cannot be changed", ctx do
      {out, 1} = run_step(ctx, GH_RC: "1")

      assert out =~ "::error::Created Jira ticket DEV-4242 but could not add it to the title"
    end
  end

  describe "a token without permission" do
    for code <- ["401", "403"] do
      test "warns and lets the job go on on HTTP #{code}", ctx do
        {out, 0} = run_step(ctx, CURL_CODE: unquote(code), CURL_BODY: ~s({"code":#{unquote(code)},"message":"Unauthorized"}))

        assert out =~ "::warning::The token in ACME_JIRA_SCOPED_TOKEN_WRITE_BASE64 cannot create issues in DEV (HTTP #{unquote(code)})"
        assert out =~ ~s("message":"Unauthorized")
        refute out =~ "::error::"
        refute File.exists?(Path.join(ctx.dir, "gh-calls"))
        assert File.read!(Path.join(ctx.dir, "output")) == ""
      end
    end

    test "warns and lets the job go on when Jira says there is no access to the project", ctx do
      body =
        ~s({"errorMessages":["The target project doesn't exist or you don't have permission to create issues in it."],) <>
          ~s("errors":{"project":"The target project doesn't exist or you don't have permission to create issues in it."}})

      {out, 0} = run_step(ctx, CURL_CODE: "400", CURL_BODY: body)

      assert out =~ "::warning::"
      assert out =~ "HTTP 400"
      refute out =~ "::error::"
      refute File.exists?(Path.join(ctx.dir, "gh-calls"))
    end
  end

  describe "other Jira failures" do
    test "fail the job on a 400 for another field", ctx do
      {out, 1} = run_step(ctx, CURL_CODE: "400", CURL_BODY: ~s({"errorMessages":[],"errors":{"issuetype":"Specify a valid issue type"}}))

      assert out =~ "::error::Jira did not create the DEV ticket"
      assert out =~ "issuetype"
      refute out =~ "::warning::"
    end

    test "fail the job on a server error", ctx do
      {out, 1} = run_step(ctx, CURL_CODE: "500", CURL_BODY: "<html>oops</html>")

      assert out =~ "::error::Jira did not create the DEV ticket for #{@pr_url} (HTTP 500): <html>oops</html>"
    end

    test "fail the job with an error on a reply with no body", ctx do
      {out, 1} = run_step(ctx, CURL_CODE: "502", NO_BODY: "1")

      assert out =~ "::error::Jira did not create the DEV ticket for #{@pr_url} (HTTP 502): no response body"
    end

    test "fail the job on a 201 without a key", ctx do
      {out, 1} = run_step(ctx, CURL_BODY: ~s({"id":"1"}))

      assert out =~ "::error::Jira did not create the DEV ticket"
    end

    test "fail the job on a network error", ctx do
      {out, 1} = run_step(ctx, CURL_RC: "28", CURL_CODE: "000")

      assert out =~ "::error::The Jira create call for #{@pr_url} did not complete"
    end
  end

  describe "the token" do
    test "never shows in the log, the outputs or a command line", ctx do
      for env <- [[], [CURL_CODE: "401"], [CURL_CODE: "500"], [GH_RC: "1"]] do
        {out, _} = run_step(ctx, env)
        refute out =~ @token
      end

      refute File.read!(Path.join(ctx.dir, "curl-args")) =~ @token
      refute File.read!(Path.join(ctx.dir, "gh-calls")) =~ @token
      refute File.read!(Path.join(ctx.dir, "output")) =~ @token
    end

    test "goes to curl in a header file that only the owner can read", ctx do
      {_out, 0} = run_step(ctx)

      assert File.read!(Path.join(ctx.dir, "auth-header")) == "Authorization: Basic #{@token}\n"
      assert File.exists?(Path.join(ctx.dir, "auth-header-is-0600"))
    end
  end

  defp run_step(ctx, overrides \\ []) do
    output = Path.join(ctx.dir, "output")
    File.write!(output, "")
    File.rm(Path.join(ctx.dir, "gh-calls"))
    File.rm(Path.join(ctx.dir, "curl-args"))

    env =
      [
        PATH: "#{ctx.bin}:#{System.get_env("PATH")}",
        STUB_DIR: ctx.dir,
        GITHUB_OUTPUT: output,
        JIRA_BASE64: @token,
        JIRA_CLOUD_ID: "cloud-1",
        PR_URL: @pr_url,
        PR_TITLE: "chore: backport phoenix_starter_kit updates",
        PR_NUMBER: "7",
        REPO: "gadabout/acme-wallets-app",
        REPO_NAME: "acme-wallets-app",
        SUMMARY_FILE: ctx.summary,
        CURL_CODE: "201",
        CURL_BODY: ~s({"id":"1","key":"DEV-4242"}),
        CURL_RC: "0",
        NO_BODY: "",
        GH_RC: "0"
      ]
      |> Keyword.merge(overrides)
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)

    System.cmd("bash", ["-e", ctx.script], env: env, stderr_to_stdout: true)
  end

  defp gh_calls(ctx), do: ctx.dir |> Path.join("gh-calls") |> File.read!() |> String.split("\n", trim: true)

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
