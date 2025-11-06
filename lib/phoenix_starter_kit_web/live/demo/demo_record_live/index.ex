defmodule PhoenixStarterKitWeb.Demo.DemoRecordLive.Index do
  use PhoenixStarterKitWeb, :live_view

  alias PhoenixStarterKit.Demo

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <span data-integration="page-title">Listing Demo records</span>
      <:actions>
        <.button variant="primary" navigate={~p"/demo/demo_records/new"}>
          <.icon name="hero-plus" /> New Demo record
        </.button>
      </:actions>
    </.header>

    <.table
      id="demo_records"
      rows={@streams.demo_records}
      row_click={fn {_id, demo_record} -> JS.navigate(~p"/demo/demo_records/#{demo_record}") end}
    >
      <:col :let={{_id, demo_record}} label="Name">
        <span data-integration={"demo-record-name-#{demo_record.id}"}>{demo_record.name}</span>
      </:col>
      <:col :let={{_id, demo_record}} label="Description">{demo_record.description}</:col>
      <:col :let={{_id, demo_record}} label="Count">{demo_record.count}</:col>
      <:col :let={{_id, demo_record}} label="Rating">{demo_record.rating}</:col>
      <:col :let={{_id, demo_record}} label="Price">{demo_record.price}</:col>
      <:col :let={{_id, demo_record}} label="Active">{demo_record.active}</:col>
      <:col :let={{_id, demo_record}} label="Tags">{demo_record.tags}</:col>
      <:col :let={{_id, demo_record}} label="Published on">{demo_record.published_on}</:col>
      <:col :let={{_id, demo_record}} label="Alarm time">{demo_record.alarm_time}</:col>
      <:col :let={{_id, demo_record}} label="Naive event at">{demo_record.naive_event_at}</:col>
      <:col :let={{_id, demo_record}} label="Status">{demo_record.status}</:col>
      <:action :let={{_id, demo_record}}>
        <div class="sr-only">
          <.link navigate={~p"/demo/demo_records/#{demo_record}"}>Show</.link>
        </div>
        <.link navigate={~p"/demo/demo_records/#{demo_record}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, demo_record}}>
        <.link phx-click={JS.push("delete", value: %{id: demo_record.id}) |> hide("##{id}")} data-confirm="Are you sure?">
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Demo records")
     |> stream(:demo_records, Demo.list_demo_records())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    demo_record = Demo.get_demo_record!(id)
    {:ok, _} = Demo.delete_demo_record(demo_record)

    {:noreply, stream_delete(socket, :demo_records, demo_record)}
  end
end
