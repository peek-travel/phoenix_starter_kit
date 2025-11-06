defmodule PhoenixStarterKitWeb.IntegrationTestHelpers do
  @moduledoc """
  Helpers for integration testing with Phoenix LiveView and Floki.
  """
  def integration_test_element(live_view, element_name) do
    live_view
    |> Phoenix.LiveViewTest.element("[data-integration='#{element_name}']")
  end

  def integration_test_element(live_view, element_name, element_text) do
    live_view
    |> Phoenix.LiveViewTest.element("[data-integration='#{element_name}']", element_text)
  end

  def render_integration_test_element(live_view, element_name) do
    live_view
    |> integration_test_element(element_name)
    |> Phoenix.LiveViewTest.render()
  end

  def text_for_integration_test_element(live_view, element_name) do
    live_view
    |> render_integration_test_element(element_name)
    |> Floki.parse_fragment!()
    |> Floki.text()
    |> String.trim()
  end

  def click_integration_test_element(live_view, element_name) do
    live_view
    |> integration_test_element(element_name)
    |> Phoenix.LiveViewTest.render_click()
  end

  def get_integration_test_attribute(live_view, element_name, attribute) do
    live_view
    |> render_integration_test_element(element_name)
    |> Floki.parse_fragment!()
    |> Floki.attribute(attribute)
  end
end
