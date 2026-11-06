defmodule PhoenixStarterKit.Github.StarterKitUpdateSecretsTest do
  @moduledoc """
  Checks which steps of .github/workflows/starter-kit-update.yml get which
  secret, the Claude allowlist and the Claude Code version. Runs the Claude
  auth lines of the backport and sweep steps with a stub `claude`.
  """
  use ExUnit.Case, async: true

  @workflow ".github/workflows/starter-kit-update.yml"
  @bot_token "${{ secrets.APP_UPDATES_GH_TOKEN || secrets.ACME_CI_GITHUB_TOKEN || secrets.GH_TOKEN }}"
  @claude_key "${{ secrets.APP_UPDATES_CLAUDE_API_KEY }}"
  @backport_step "Run starter-kit-update skill (backport)"
  @sweep_step "Run starter-kit-update skill (dependency + Docker image sweep)"

  @moduletag :tmp_dir

  # A child repo that removed the workflow has nothing to test here.
  unless File.exists?(@workflow), do: @moduletag(skip: "no #{@workflow} in this repo")

  describe "the job env" do
    test "has no secret, only the bot token check" do
      assert job_env() |> Enum.map(&(&1 |> String.trim() |> String.split(":") |> hd())) |> Enum.sort() ==
               Enum.sort(~w(HAS_BOT_TOKEN BASE_BRANCH MAX_FIX_ATTEMPTS CLAUDE_CODE_VERSION CLAUDE_ALLOWED_TOOLS CLAUDE_MODEL_ARGS))

      assert [has_bot_token] = Enum.filter(job_env(), &(&1 =~ "secrets."))
      assert String.trim(has_bot_token) =~ ~r/^HAS_BOT_TOKEN: \$\{\{ [^}]+ \}\}$/
      assert has_bot_token |> String.split("secrets.") |> tl() |> Enum.all?(&(&1 =~ ~r/^\w+ != ''/))
    end
  end

  describe "secrets by step" do
    test "only the push, PR, Jira and Mark PR ready steps get the bot token" do
      assert steps_with(@bot_token) ==
               [
                 "Push branch and open draft PR",
                 "Create Jira ticket (gadabout)",
                 "Push fix (attempt 1)",
                 "Push fix (attempt 2)",
                 "Mark PR ready for review"
               ]

      for name <- steps_with(@bot_token), do: assert("          GH_TOKEN: #{@bot_token}" in step(name))
    end

    test "only the Claude steps and the check of the key get the Claude key" do
      assert steps_with(@claude_key) == [
               "Validate Claude auth",
               @backport_step,
               @sweep_step,
               "Fix CI (attempt 1)",
               "Fix CI (attempt 2)"
             ]

      refute step_text("Validate Claude auth") =~ "claude -p"
      refute step_text("Validate Claude auth") =~ "GITHUB_ENV"
    end

    test "only the Slack steps get the Slack webhook" do
      assert steps_with("secrets.SLACK_WEBHOOK_URL") == ["Slack notify - success", "Slack notify - failure"]
    end

    test "every secret is in the env of a step, never in a script" do
      for {name, lines} <- steps(), line <- lines, line =~ ~r/secrets\.[A-Z]/ do
        assert line =~ ~r/^          [A-Z_0-9]+: \$\{\{/, "#{name} uses a secret outside its env: #{line}"
      end
    end

    test "steps that run claude or mix get no GitHub token and no Slack webhook" do
      # "Fix CI (attempt 2)" runs the script of attempt 1 (`run: *fix_ci`).
      claude_or_mix =
        for {name, lines} <- steps(),
            text = Enum.join(lines, "\n"),
            text =~ "claude -p" or text =~ ~r/\bmix / or text =~ "run: *fix_ci",
            do: {name, text}

      assert Enum.map(claude_or_mix, &elem(&1, 0)) == [
               "Install hex and rebar",
               @backport_step,
               "Re-install hex and rebar for the re-synced toolchain",
               @sweep_step,
               "Fix CI (attempt 1)",
               "Fix CI (attempt 2)"
             ]

      for {name, text} <- claude_or_mix, secret <- ["GH_TOKEN", "GITHUB_TOKEN", "SLACK_WEBHOOK_URL", "CHECKS_READ_TOKEN"] do
        refute text =~ secret, "#{name} gets #{secret}"
      end
    end

    test "the checkout keeps no token in .git/config" do
      checkout = step("actions/checkout@v7")

      assert "          persist-credentials: false" in checkout
      refute Enum.any?(checkout, &(&1 =~ "token"))
    end

    test "the upstream history comes from a fetch with no token" do
      fetch = step("Fetch phoenix_starter_kit history")

      assert "        run: git fetch --no-tags https://github.com/peek-travel/phoenix_starter_kit.git +main:refs/remotes/starter-kit/main" in fetch
      refute Enum.any?(fetch, &(&1 =~ "env:"))
    end
  end

  describe "the Claude allowlist" do
    test "has only exact git commands and no gh" do
      tools = allowed_tools()

      refute "Bash(git:*)" in tools
      refute Enum.any?(tools, &String.starts_with?(&1, "Bash(gh"))
      refute "Bash(base64:*)" in tools

      assert tools |> Enum.filter(&String.starts_with?(&1, "Bash(git")) |> Enum.sort() ==
               Enum.sort(~w(status diff log show add rm mv commit revert) |> Enum.map(&"Bash(git #{&1}:*)"))
    end

    test "every claude call uses it under dontAsk" do
      text = File.read!(@workflow)
      claude_calls = length(String.split(text, "claude -p ")) - 1

      assert claude_calls == 3
      assert length(String.split(text, ~s(--allowedTools "$CLAUDE_ALLOWED_TOOLS"))) - 1 == claude_calls
      assert length(String.split(text, "--permission-mode dontAsk")) - 1 == claude_calls
      refute text =~ "bypassPermissions\n"
    end
  end

  describe "the Claude Code version" do
    test "is one fixed version, in the install and in the cache key" do
      assert [_, version] = Regex.run(~r/^      CLAUDE_CODE_VERSION: (\S+)$/m, File.read!(@workflow))
      assert version =~ ~r/^\d+\.\d+\.\d+$/

      assert ~s(        run: npm install -g "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION") in step("Install Claude Code CLI")
      assert "          key: npm-cache-${{ runner.os }}-claude-code-${{ env.CLAUDE_CODE_VERSION }}" in step("Cache npm downloads")
    end
  end

  describe "the Claude auth lines" do
    setup %{tmp_dir: dir} do
      bin = Path.join(dir, "bin")
      File.mkdir_p!(bin)

      claude = Path.join(bin, "claude")

      File.write!(claude, ~S"""
      #!/usr/bin/env bash
      env > "$STUB_DIR/claude-env"
      echo "BASH_ENV=/tmp/x" >> "$STUB_DIR/github-env"
      echo "/tmp/x" >> "$STUB_DIR/github-path"
      exit "${CLAUDE_RC:-0}"
      """)

      File.chmod!(claude, 0o755)
      %{dir: dir, bin: bin}
    end

    for name <- [@backport_step, @sweep_step] do
      test "#{name}: sets the variable for the key kind and empties the runner files", ctx do
        {_out, 0} = run_claude_step(ctx, unquote(name), " sk-ant-api03-claude-key-for-the-tests\n")

        env = File.read!(Path.join(ctx.dir, "claude-env"))
        assert env =~ "\nANTHROPIC_API_KEY=sk-ant-api03-claude-key-for-the-tests\n"
        refute env =~ "CLAUDE_CODE_OAUTH_TOKEN=", "claude got CLAUDE_CODE_OAUTH_TOKEN"

        for var <- ["CLAUDE_AUTH_VALUE=", "GITHUB_ENV=", "GITHUB_PATH=", "GITHUB_OUTPUT="] do
          refute env =~ "\n" <> var, "claude got #{var}"
        end

        assert File.read!(Path.join(ctx.dir, "github-env")) == ""
        assert File.read!(Path.join(ctx.dir, "github-path")) == ""
      end

      test "#{name}: sets the OAuth variable for an OAuth token", ctx do
        {_out, 0} = run_claude_step(ctx, unquote(name), "sk-ant-oat01-oauth-token-for-the-tests")

        env = File.read!(Path.join(ctx.dir, "claude-env"))
        assert env =~ "\nCLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-oauth-token-for-the-tests\n"
        refute env =~ "ANTHROPIC_API_KEY=", "claude got ANTHROPIC_API_KEY"
      end

      test "#{name}: fails when claude fails, after it empties the runner files", ctx do
        {_out, 3} = run_claude_step(ctx, unquote(name), "sk-ant-api03-claude-key-for-the-tests", CLAUDE_RC: "3")

        assert File.read!(Path.join(ctx.dir, "github-env")) == ""
      end
    end
  end

  describe "Validate Claude auth" do
    setup %{tmp_dir: dir}, do: %{dir: dir}

    test "accepts both key kinds and exports nothing", ctx do
      for value <- ["sk-ant-api03-claude-key-for-the-tests", " sk-ant-oat01-oauth-token-for-the-tests\n"] do
        {_out, 0} = run_validate(ctx, value)
        assert File.read!(Path.join(ctx.dir, "github-env")) == ""
      end
    end

    test "rejects an empty, short or unknown value" do
      for {value, message} <- [
            {"", "APP_UPDATES_CLAUDE_API_KEY is not set"},
            {"sk-ant-api03-short", "looks too short"},
            {"not-an-anthropic-credential-value", "doesn't look like a recognized Anthropic credential"}
          ] do
        dir = Path.join(System.tmp_dir!(), "validate-#{System.unique_integer([:positive])}")
        File.mkdir_p!(dir)
        {out, 1} = run_validate(%{dir: dir}, value)
        assert out =~ message
        File.rm_rf!(dir)
      end
    end
  end

  defp run_claude_step(ctx, name, key, overrides \\ []) do
    script =
      name
      |> step_script()
      |> String.replace("${{ steps.branch.outputs.name }}", "chore/update-1")

    run(ctx, script, [PATH: "#{ctx.bin}:#{System.get_env("PATH")}", CLAUDE_AUTH_VALUE: key] ++ overrides)
  end

  defp run_validate(ctx, value), do: run(ctx, step_script("Validate Claude auth"), CLAUDE_AUTH_VALUE: value)

  defp run(ctx, script, env) do
    path = Path.join(ctx.dir, "step.sh")
    File.write!(path, script)
    for file <- ["github-env", "github-path", "output"], do: File.write!(Path.join(ctx.dir, file), "")

    env =
      [
        STUB_DIR: ctx.dir,
        GITHUB_OUTPUT: Path.join(ctx.dir, "output"),
        GITHUB_ENV: Path.join(ctx.dir, "github-env"),
        GITHUB_PATH: Path.join(ctx.dir, "github-path"),
        CLAUDE_ALLOWED_TOOLS: "Read",
        CLAUDE_MODEL_ARGS: "",
        ANTHROPIC_API_KEY: nil,
        CLAUDE_CODE_OAUTH_TOKEN: nil,
        CLAUDE_RC: "0"
      ]
      |> Keyword.merge(env)
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)

    System.cmd("bash", ["-e", path], env: env, stderr_to_stdout: true)
  end

  defp workflow_lines, do: @workflow |> File.read!() |> String.split("\n")

  # The lines of the job's `env:` block.
  defp job_env do
    workflow_lines()
    |> Enum.drop_while(&(&1 != "    env:"))
    |> Enum.drop(1)
    |> Enum.take_while(&(&1 != "    steps:"))
    |> Enum.filter(&(&1 =~ ~r/^      [A-Z_]+:/))
  end

  # Each step as {name, lines}. A step with no name (the checkout) is
  # named after its `uses:`.
  defp steps do
    workflow_lines()
    |> Enum.drop_while(&(&1 != "    steps:"))
    |> Enum.drop(1)
    |> Enum.chunk_while(
      [],
      fn line, acc ->
        if String.starts_with?(line, "      - ") and acc != [], do: {:cont, Enum.reverse(acc), [line]}, else: {:cont, [line | acc]}
      end,
      fn acc -> {:cont, Enum.reverse(acc), []} end
    )
    |> Enum.filter(&String.starts_with?(hd(&1), "      - "))
    |> Enum.map(fn [first | _] = lines -> {first |> String.replace(~r/^      - (name|uses): /, ""), drop_comments(lines)} end)
  end

  # Drops the comment lines that come before the next step.
  defp drop_comments(lines), do: lines |> Enum.reverse() |> Enum.drop_while(&(&1 =~ ~r/^\s*(#.*)?$/)) |> Enum.reverse()

  defp steps_with(text), do: for({name, lines} <- steps(), Enum.any?(lines, &String.contains?(&1, text)), do: name)

  defp step(name) do
    case List.keyfind(steps(), name, 0) do
      {^name, lines} -> lines
      nil -> flunk("no step named #{inspect(name)} in #{@workflow}")
    end
  end

  defp step_text(name), do: name |> step() |> Enum.join("\n")

  # The `run: |` block, without its 10-space YAML indent.
  defp step_script(name) do
    step(name)
    |> Enum.drop_while(&(not (&1 =~ ~r/^        run: (&\w+ )?\|$/)))
    |> Enum.drop(1)
    |> Enum.take_while(&(&1 == "" or String.starts_with?(&1, "          ")))
    |> Enum.map_join("\n", &String.replace_prefix(&1, "          ", ""))
  end

  defp allowed_tools do
    [_, tools] = Regex.run(~r/^      CLAUDE_ALLOWED_TOOLS: "(.*)"$/m, File.read!(@workflow))
    tools |> String.replace(~S(\"), ~S(")) |> String.split(",")
  end
end
