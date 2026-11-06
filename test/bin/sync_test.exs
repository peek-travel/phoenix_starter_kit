defmodule PhoenixStarterKit.Bin.SyncTest do
  @moduledoc """
  Runs bin/sync with a stub `curl`. It checks how the script reads `.env`
  and how it gives the registry token to curl.
  """
  use ExUnit.Case, async: true

  @script Path.expand("bin/sync")

  @moduletag :tmp_dir

  # A child repo that removed the script has nothing to test here.
  unless File.exists?(@script), do: @moduletag(skip: "no bin/sync in this repo")

  # Records its argv (one arg per line) and its stdin, then answers 200.
  @curl_stub ~S"""
  #!/usr/bin/env bash
  printf '%s\n' "$@" > "$STUB_DIR/curl-argv"
  cat > "$STUB_DIR/curl-stdin"
  printf '{"data":{"action":"updated","app":{"id":"app-1"}}}\nHTTP_STATUS:200'
  """

  setup %{tmp_dir: dir} do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)
    curl = Path.join(bin, "curl")
    File.write!(curl, @curl_stub)
    File.chmod!(curl, 0o755)

    File.write!(Path.join(dir, "app.json"), ~s({"data":{"app":{"id":"app-1"}}}))

    %{dir: dir, bin: bin}
  end

  defp run_sync(%{dir: dir, bin: bin}, env_file, args \\ ["app.json"], extra_env \\ []) do
    File.write!(Path.join(dir, ".env"), env_file)

    env =
      [
        {"PATH", "#{bin}:#{System.get_env("PATH")}"},
        {"STUB_DIR", dir},
        {"PEEK_APP_REGISTRY_URL", nil},
        {"PEEK_APP_REGISTRY_AUTH_TOKEN", nil}
      ] ++ extra_env

    System.cmd("bash", ["-c", ~s(printf 'yes\\n' | "$0" "$@"), @script | args], cd: dir, env: env, stderr_to_stdout: true)
  end

  defp curl_argv(dir), do: dir |> Path.join("curl-argv") |> File.read!()
  defp curl_stdin(dir), do: dir |> Path.join("curl-stdin") |> File.read!()

  test "the upsert call gets the Authorization header on stdin, not in argv", %{dir: dir} = ctx do
    {output, 0} = run_sync(ctx, "PEEK_APP_REGISTRY_URL=https://registry.test\nPEEK_APP_REGISTRY_AUTH_TOKEN=secret-token-1\n")

    assert output =~ "Complete: action updated"
    assert curl_stdin(dir) == ~s(header = "Authorization: Bearer secret-token-1"\n)
    argv = curl_argv(dir)
    assert argv =~ "--config\n-\n"
    assert argv =~ "https://registry.test/apps/upsert?auto-publish=true"
    refute argv =~ "secret-token-1"
  end

  test "the --pull call gets the Authorization header on stdin, not in argv", %{dir: dir} = ctx do
    System.cmd("git", ["init", "-q"], cd: dir)

    {output, 0} =
      run_sync(ctx, "PEEK_APP_REGISTRY_URL=https://registry.test\nPEEK_APP_REGISTRY_AUTH_TOKEN=secret-token-2\n", ["app.json", "--pull"])

    assert output =~ "Updated app.json from registry"
    assert curl_stdin(dir) == ~s(header = "Authorization: Bearer secret-token-2"\n)
    argv = curl_argv(dir)
    assert argv =~ "https://registry.test/apps/app-1/export"
    refute argv =~ "secret-token-2"
  end

  test "does not run commands from .env", %{dir: dir} = ctx do
    marker = Path.join(dir, "ran")

    {_output, 0} =
      run_sync(ctx, """
      touch #{marker}
      PEEK_APP_REGISTRY_URL=https://registry.test
      PEEK_APP_REGISTRY_AUTH_TOKEN=$(touch #{marker})`touch #{marker}`
      """)

    refute File.exists?(marker)
    assert curl_stdin(dir) =~ "Bearer $(touch #{marker})`touch #{marker}`"
  end

  test "reads export prefixes, quotes, comments and CRLF line ends", %{dir: dir} = ctx do
    {_output, 0} =
      run_sync(
        ctx,
        ~s(# comment\r\nexport PEEK_APP_REGISTRY_URL="https://registry.test" # see "docs"\r\nPEEK_APP_REGISTRY_AUTH_TOKEN='tok en' \r\n)
      )

    assert curl_argv(dir) =~ "https://registry.test/apps/upsert"
    assert curl_stdin(dir) == ~s(header = "Authorization: Bearer tok en"\n)
  end

  test "removes a comment after an unquoted value and uses the last line for a key", %{dir: dir} = ctx do
    {_output, 0} =
      run_sync(
        ctx,
        "PEEK_APP_REGISTRY_URL=https://old.test\nPEEK_APP_REGISTRY_URL=https://registry.test # stage\nPEEK_APP_REGISTRY_AUTH_TOKEN=t1\n"
      )

    assert curl_argv(dir) =~ "https://registry.test/apps/upsert?"
  end

  test "escapes quotes and backslashes in the token for the curl config", %{dir: dir} = ctx do
    {_output, 0} = run_sync(ctx, ~s(PEEK_APP_REGISTRY_URL=https://registry.test\nPEEK_APP_REGISTRY_AUTH_TOKEN='a"b\\c'\n))

    assert curl_stdin(dir) == ~s(header = "Authorization: Bearer a\\"b\\\\c"\n)
  end

  test "uses a value from the environment when .env does not have the key", %{dir: dir} = ctx do
    {_output, 0} =
      run_sync(ctx, "PEEK_APP_REGISTRY_URL=https://registry.test\n", ["app.json"], [{"PEEK_APP_REGISTRY_AUTH_TOKEN", "env-token"}])

    assert curl_stdin(dir) == ~s(header = "Authorization: Bearer env-token"\n)
  end

  test "stops when the token is missing", ctx do
    {output, 1} = run_sync(ctx, "PEEK_APP_REGISTRY_URL=https://registry.test\n")

    assert output =~ "Missing PEEK_APP_REGISTRY_AUTH_TOKEN in .env"
  end
end
