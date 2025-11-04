defmodule PhoenixStarterKitWeb.Widget.WidgetControllerTest do
  use PhoenixStarterKitWeb.ConnCase, async: true

  describe "GET /widget/your_end_point" do
    test "returns success when peek_install_id is present", %{conn: conn} do
      peek_install_id = "install-#{System.unique_integer()}"

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "returns success when peek_install_id is present with any parameters", %{conn: conn} do
      peek_install_id = "install-#{System.unique_integer()}"

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> get(~p"/widget/your_end_point", %{"activity_id" => "test-activity-123", "other_param" => "value"})

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "returns unauthorized when peek_install_id is not present", %{conn: conn} do
      conn = get(conn, ~p"/widget/your_end_point")

      assert json_response(conn, 401) == %{
               "error" => "Unauthorized"
             }
    end

    test "returns success when peek_install_id is nil (pattern matches any value)", %{conn: conn} do
      conn =
        conn
        |> assign(:peek_install_id, nil)
        |> get(~p"/widget/your_end_point")

      # The pattern %{assigns: %{peek_install_id: _}} matches ANY value, including nil
      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "returns unauthorized when peek_install_id is not in assigns", %{conn: conn} do
      # Don't assign peek_install_id at all - this is the only case that fails to match
      conn = get(conn, ~p"/widget/your_end_point", %{"some_param" => "value"})

      assert json_response(conn, 401) == %{
               "error" => "Unauthorized"
             }
    end

    test "returns success with different peek_install_id formats", %{conn: _conn} do
      # Test with different install ID formats
      test_cases = [
        "install-123",
        "install-#{System.unique_integer()}",
        "some-long-installation-id-with-dashes",
        "InstallID123"
      ]

      for install_id <- test_cases do
        conn =
          build_conn()
          |> assign(:peek_install_id, install_id)
          |> get(~p"/widget/your_end_point")

        assert json_response(conn, 200) == %{
                 "ok" => "true",
                 "message" => "Hello from PhoenixStarterKit"
               }
      end
    end

    test "function clause matching works correctly", %{conn: conn} do
      # Test that the first function clause matches when peek_install_id is present
      peek_install_id = "test-install-id"

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }

      # Test that the second function clause matches when peek_install_id is not present
      conn =
        build_conn()
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 401) == %{
               "error" => "Unauthorized"
             }
    end
  end

  describe "OPTIONS /widget/your_end_point" do
    test "returns 200 for CORS preflight request", %{conn: conn} do
      conn = options(conn, ~p"/widget/your_end_point")

      assert response(conn, 200) == ""
    end

    test "returns 200 for CORS preflight request with any parameters", %{conn: conn} do
      conn = options(conn, ~p"/widget/your_end_point", %{"some" => "params"})

      assert response(conn, 200) == ""
    end

    test "sets CORS headers through the CORS plug", %{conn: conn} do
      conn = options(conn, ~p"/widget/your_end_point")

      # The CORS headers should be set by the CORS plug in the pipeline
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, PUT, DELETE, OPTIONS"]
      assert get_resp_header(conn, "access-control-allow-headers") == ["*"]
      assert get_resp_header(conn, "access-control-max-age") == ["86400"]
    end
  end

  describe "widget_api pipeline integration" do
    test "CORS headers are present on GET requests", %{conn: conn} do
      peek_install_id = "install-#{System.unique_integer()}"

      conn =
        conn
        |> assign(:peek_install_id, peek_install_id)
        |> get(~p"/widget/your_end_point")

      # Verify CORS headers are set by the pipeline
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, PUT, DELETE, OPTIONS"]
      assert get_resp_header(conn, "access-control-allow-headers") == ["*"]
      assert get_resp_header(conn, "access-control-max-age") == ["86400"]
    end

    test "accepts JSON content type", %{conn: conn} do
      peek_install_id = "install-#{System.unique_integer()}"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> assign(:peek_install_id, peek_install_id)
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "handles requests without peek_install_id through pipeline", %{conn: conn} do
      # Test that the pipeline doesn't interfere with the controller's logic
      conn = get(conn, ~p"/widget/your_end_point")

      assert json_response(conn, 401) == %{
               "error" => "Unauthorized"
             }

      # CORS headers should still be present even on error responses
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end

  describe "edge cases and pattern matching behavior" do
    test "handles empty string peek_install_id (pattern matches)", %{conn: conn} do
      conn =
        conn
        |> assign(:peek_install_id, "")
        |> get(~p"/widget/your_end_point")

      # Empty string still matches the pattern %{assigns: %{peek_install_id: _}}
      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "handles non-string peek_install_id (pattern matches)", %{conn: conn} do
      # Test with integer - pattern matches any value
      conn =
        conn
        |> assign(:peek_install_id, 123)
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "handles atom peek_install_id (pattern matches)", %{conn: conn} do
      # Test with atom - pattern matches any value
      conn =
        conn
        |> assign(:peek_install_id, :some_atom)
        |> get(~p"/widget/your_end_point")

      assert json_response(conn, 200) == %{
               "ok" => "true",
               "message" => "Hello from PhoenixStarterKit"
             }
    end

    test "only fails when peek_install_id key is missing entirely", %{conn: conn} do
      # This is the only case that should return 401
      conn = get(conn, ~p"/widget/your_end_point")

      assert json_response(conn, 401) == %{
               "error" => "Unauthorized"
             }
    end
  end
end
