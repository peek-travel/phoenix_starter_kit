defmodule PhoenixStarterKit.Bin.DevSecretsTest do
  @moduledoc """
  Runs bin/dev-secrets, which writes the dev secret_key_base and LiveView
  signing salt that config/dev.exs reads.
  """
  use ExUnit.Case, async: true

  @script "bin/dev-secrets"

  @moduletag :tmp_dir

  defp run_script(path) do
    {output, status} = System.cmd(Path.expand(@script), [path], stderr_to_stdout: true)
    assert status == 0, output
    output
  end

  defp read_secrets(path) do
    {secrets, _binding} = Code.eval_file(path)
    secrets
  end

  test "writes a secret_key_base and a LiveView signing salt", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "config/dev.secret.exs")

    assert run_script(path) =~ "Wrote #{path}."

    secrets = read_secrets(path)
    assert Keyword.keys(secrets) == [:secret_key_base, :live_view_signing_salt]
    assert String.length(secrets[:secret_key_base]) == 64
    assert String.length(secrets[:live_view_signing_salt]) == 32
    assert File.stat!(path).mode |> Bitwise.band(0o077) == 0
  end

  test "2 runs make different values", %{tmp_dir: tmp_dir} do
    first = Path.join(tmp_dir, "first.exs")
    second = Path.join(tmp_dir, "second.exs")

    run_script(first)
    run_script(second)

    first_secrets = read_secrets(first)
    second_secrets = read_secrets(second)
    assert first_secrets[:secret_key_base] != second_secrets[:secret_key_base]
    assert first_secrets[:live_view_signing_salt] != second_secrets[:live_view_signing_salt]
  end

  test "keeps a file that exists", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "dev.secret.exs")
    run_script(path)
    contents = File.read!(path)

    assert run_script(path) =~ "Kept #{path}: it exists."
    assert File.read!(path) == contents
  end
end
