defmodule PhoenixStarterKitWeb.SettingsLive do
  use PhoenixStarterKitWeb, :live_view

  @doc """
  Mount function that initializes the LiveView with the current partner user data.
  """
  def mount(_params, _session, socket) do
    %{
      current_partner_user:
        %{
          partner: partner
        } = partner_user
    } = socket.assigns

    socket = assign(socket, :partner_user, partner_user)
    socket = assign(socket, :partner, partner)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.alert color="info">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            Welcome!
            <div class="ml-2 text-sm text-gray-600">
              You are logged in as {@partner_user.email} for {@partner.name}.
            </div>
          </div>
          <%= if @partner.is_test do %>
            <span class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-800 ring-1 ring-inset ring-yellow-600/20">
              Test Account
            </span>
          <% end %>
        </div>
      </.alert>

      <.divider />

      <.message>
        Check out the demo:
        <.link class="underline" href={~p"/demo/demo_records"}>
          Core Components
        </.link>
      </.message>
    </Layouts.app>
    """
  end
end
