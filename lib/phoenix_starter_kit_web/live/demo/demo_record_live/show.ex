defmodule PhoenixStarterKitWeb.Demo.DemoRecordLive.Show do
  use PhoenixStarterKitWeb, :live_view

  alias PhoenixStarterKit.Demo

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Demo record {@demo_record.id}
      <:subtitle>This is a demo_record record from your database.</:subtitle>
      <:actions>
        <.button navigate={~p"/demo/demo_records"}>
          <.icon name="hero-arrow-left" />
        </.button>
        <.button variant="primary" navigate={~p"/demo/demo_records/#{@demo_record}/edit?return_to=show"}>
          <.icon name="hero-pencil-square" /> Edit demo_record
        </.button>
      </:actions>
    </.header>

    <.list>
      <:item title="Name">{@demo_record.name}</:item>
      <:item title="Description">{@demo_record.description}</:item>
      <:item title="Count">{@demo_record.count}</:item>
      <:item title="Rating">{@demo_record.rating}</:item>
      <:item title="Price">{@demo_record.price}</:item>
      <:item title="Active">{@demo_record.active}</:item>
      <:item title="Tags">{@demo_record.tags}</:item>
      <:item title="Published on">{@demo_record.published_on}</:item>
      <:item title="Alarm time">{@demo_record.alarm_time}</:item>
      <:item title="Naive event at">{@demo_record.naive_event_at}</:item>
      <:item title="Status">{@demo_record.status}</:item>
    </.list>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Demo record")
     |> assign(:demo_record, Demo.get_demo_record!(id))}
  end
end
