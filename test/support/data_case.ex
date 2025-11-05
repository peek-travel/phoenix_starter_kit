defmodule PhoenixStarterKit.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PhoenixStarterKit.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  require Logger
  import Mimic

  using do
    quote do
      use Mimic

      alias PhoenixStarterKit.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import PhoenixStarterKit.DataCase
      import PhoenixStarterKitWeb.IntegrationTestHelpers
    end
  end

  setup tags do
    PhoenixStarterKit.DataCase.setup_sandbox(tags)
    PhoenixStarterKit.DataCase.mock_external()

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PhoenixStarterKit.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def mock_external do
    # Copy and mock PeekAppSDK.Metrics for metrics tracking
    copy(PeekAppSDK.Metrics)

    stub(PeekAppSDK.Metrics, :track_install, fn _external_refid, _name, _is_test ->
      {:ok, %{}}
    end)

    stub(PeekAppSDK.Metrics, :track_uninstall, fn _external_refid, _name, _is_test ->
      {:ok, %{}}
    end)

    # Also mock the main Tesla module for any other Tesla clients
    copy(Tesla)

    stub(Tesla, :request, fn env, _opts ->
      case env do
        %Tesla.Env{
          method: :post,
          url: "http://noreaga.peek.test/apps/backoffice-gql/app-id/" <> operation_name,
          body: body
        } ->
          %{"query" => query, "variables" => variables} = Jason.decode!(body)
          {:ok, PhoenixStarterKit.Test.PeekProMock.mock_response(operation_name, query, variables)}

        env ->
          # For any other requests, return a generic error
          {:error, "Unmocked request: #{inspect(env)}"}
      end
    end)
  end
end
