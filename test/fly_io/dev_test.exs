defmodule PhoenixStarterKit.FlyIo.DevTest do
  @moduledoc """
  Sources the Cloudflare tunnel dev script (fly-io/dev, or bin/dev after
  bin/enable-flyio) and calls its tunnel functions with a stub `cloudflared`.
  """
  use ExUnit.Case, async: true

  @script ["fly-io/dev", "bin/dev"] |> Enum.map(&Path.expand/1) |> Enum.find(&File.exists?/1)

  @moduletag :tmp_dir

  # A child repo without the script has nothing to test here.
  unless @script, do: @moduletag(skip: "no fly-io/dev or bin/dev in this repo")

  # Records each call. `tunnel list` prints $TUNNELS under a header, or fails
  # when $LIST_FAILS is set.
  @cloudflared_stub ~S"""
  #!/usr/bin/env bash
  printf '%s\n' "$*" >> "$STUB_DIR/calls"
  if [ "$1 $2" = "tunnel list" ]; then
    [ -n "$LIST_FAILS" ] && { echo "list failed" >&2; exit 1; }
    printf 'ID NAME CREATED CONNECTIONS\n%b' "$TUNNELS"
  fi
  exit 0
  """

  setup %{tmp_dir: dir} do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)
    File.mkdir_p!(Path.join(dir, "home/.cloudflared"))
    stub = Path.join(bin, "cloudflared")
    File.write!(stub, @cloudflared_stub)
    File.chmod!(stub, 0o755)

    %{dir: dir, bin: bin}
  end

  defp run_dev(%{dir: dir, bin: bin}, commands, env) do
    env =
      [{"PATH", "#{bin}:#{System.get_env("PATH")}"}, {"STUB_DIR", dir}, {"HOME", Path.join(dir, "home")}, {"LIST_FAILS", nil}] ++ env

    System.cmd("bash", ["-c", ~s(set -e; source "$1"; #{commands}), "dev-test", @script], env: env, stderr_to_stdout: true)
  end

  defp calls(dir) do
    case File.read(Path.join(dir, "calls")) do
      {:ok, text} -> String.split(text, "\n", trim: true)
      {:error, :enoent} -> []
    end
  end

  test "creates the tunnel and routes DNS with --overwrite-dns when no tunnel has the exact name", %{dir: dir} = ctx do
    {output, 0} = run_dev(ctx, "create_tunnel myapp; setup_dns myapp", [{"TUNNELS", "uuid-other myapp-dev-bob 2024 x\\n"}])

    assert output =~ "Tunnel 'myapp-dev' created successfully"

    assert calls(dir) == [
             "tunnel list",
             "tunnel create myapp-dev",
             "tunnel route dns --overwrite-dns myapp-dev myapp-dev.peeklabs.com"
           ]
  end

  test "reuses the tunnel when this machine has its credentials file", %{dir: dir} = ctx do
    File.write!(Path.join(dir, "home/.cloudflared/uuid-mine.json"), "{}")

    {output, 0} =
      run_dev(ctx, "create_tunnel myapp; get_tunnel_uuid myapp; setup_dns myapp", [{"TUNNELS", "uuid-mine myapp-dev 2024 x\\n"}])

    assert output =~ "reusing existing tunnel"
    assert output =~ "uuid-mine"
    refute Enum.any?(calls(dir), &(&1 =~ ~r/tunnel (create|delete)|route dns delete|--overwrite-dns/))
  end

  test "stops and never deletes a tunnel when this machine has no credentials file", %{dir: dir} = ctx do
    {output, 1} = run_dev(ctx, "create_tunnel myapp", [{"TUNNELS", "uuid-theirs myapp-dev 2024 x\\n"}])

    assert output =~ "this machine has no credentials file"
    assert output =~ "uuid-theirs.json"
    assert calls(dir) == ["tunnel list"]
  end

  test "stops when cloudflared cannot list the tunnels", %{dir: dir} = ctx do
    {output, 1} = run_dev(ctx, "create_tunnel myapp", [{"LIST_FAILS", "1"}])

    assert output =~ "Could not list the Cloudflare tunnels"
    assert calls(dir) == ["tunnel list"]
  end

  test "runs main when it is run as a script", ctx do
    {output, 0} =
      System.cmd("bash", [@script, "--dry-run"], env: [{"PATH", "#{ctx.bin}:#{System.get_env("PATH")}"}], stderr_to_stdout: true)

    assert output =~ "DRY RUN MODE"
  end
end
