defmodule PhoenixStarterKitWeb.Demo.DemoComponentsLive do
  @moduledoc """
  This module demonstrates the usage of various components in the application.

  It's a good place to come when you want to see how things work and get ideas
  for how to build new things. It also teaches AI what elements are available.
  """
  use PhoenixStarterKitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        <span data-integration="page-title">Core Components Demo</span>
        <:subtitle>
          Explore different types of alerts available in the system.
        </:subtitle>
      </.header>

      <div class="space-y-6">
        <section>
          <h2 class="text-xl font-semibold mb-4">Basic Alerts</h2>
          <div class="space-y-4">
            <.odyssey_alert type="success">
              <:title>Success!</:title>
              <:message>This is a success alert message.</:message>
            </.odyssey_alert>

            <.odyssey_alert type="warning">
              <:title>Warning</:title>
              <:message>This is a warning alert message.</:message>
            </.odyssey_alert>

            <.odyssey_alert type="error">
              <:title>Error</:title>
              <:message>This is an error alert message.</:message>
            </.odyssey_alert>

            <.odyssey_alert type="info">
              <:title>Information</:title>
              <:message>This is an info alert message.</:message>
            </.odyssey_alert>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-semibold mb-4">Alerts with Actions</h2>
          <div class="space-y-4">
            <.odyssey_alert type="info" action_text="Take Action" action_url="#">
              <:title>Action Required</:title>
              <:message>This alert has actions you can take.</:message>
            </.odyssey_alert>

            <.odyssey_alert type="warning" action_text="Connect Account" action_url="https://example.com">
              <:title>Connect Your Account</:title>
              <:message>To get started, please connect your account.</:message>
            </.odyssey_alert>
          </div>
        </section>

        <section>
          <h2 class="text-xl font-semibold mb-4">Flash Messages</h2>

          <.button phx-click="show_flash_info">Show Flash Info</.button>
          <.button phx-click="show_flash_error">Show Flash Error</.button>
        </section>
      </div>

      <section>
        <h2 class="text-2xl font-bold">Testing daisyUI Buttons</h2>

        <button class="btn">Default</button>
        <button class="btn btn-primary">Primary</button>
        <button class="btn btn-secondary">Secondary</button>
        <button class="btn btn-tertiary">Tertiary</button>
        <button class="btn btn-danger">Danger</button>
      </section>
    </div>
    """
  end

  @impl true
  def handle_event("show_flash_info", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "This is a flash info message with a very long text to test text wrapping and overflow behavior in the flash message component."
     )}
  end

  def handle_event("show_flash_error", _params, socket) do
    {:noreply, put_flash(socket, :error, "This is a flash error message!")}
  end
end
