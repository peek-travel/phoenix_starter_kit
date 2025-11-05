defmodule PhoenixStarterKitWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PhoenixStarterKitWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      use Mimic

      # The default endpoint for testing
      @endpoint PhoenixStarterKitWeb.Endpoint

      use PhoenixStarterKitWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PhoenixStarterKitWeb.ConnCase
      import PhoenixStarterKitWeb.IntegrationTestHelpers
    end
  end

  setup tags do
    PhoenixStarterKit.DataCase.setup_sandbox(tags)
    PhoenixStarterKit.DataCase.mock_external()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in partner_users.

      setup :register_and_log_in_partner_user

  It stores an updated connection and a registered partner_user in the
  test context.
  """
  def register_and_log_in_partner_user(%{conn: conn}, partner_id \\ nil) do
    partner = PhoenixStarterKit.PartnersFixtures.partner_fixture(%{is_test: true})
    partner_user = PhoenixStarterKit.PartnersFixtures.partner_user_fixture()
    {:ok, _} = PhoenixStarterKit.Partners.connect_partner_user(partner, partner_user)
    partner_user = PhoenixStarterKit.Partners.set_current_partner(partner_user, partner_id)

    %{conn: log_in_partner_user(conn, partner_user, partner_id), partner_user: partner_user}
  end

  @doc """
  Logs the given `partner_user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_partner_user(conn, partner_user, partner_id \\ nil) do
    token = PhoenixStarterKit.Partners.generate_partner_user_session_token(partner_user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:partner_user_token, token)
    |> Plug.Conn.put_session(:current_partner_id, partner_id)
  end
end
