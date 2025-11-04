defmodule PhoenixStarterKitWeb.Demo.DemoRecordLive.Form do
  use PhoenixStarterKitWeb, :live_view

  alias PhoenixStarterKit.Demo
  alias PhoenixStarterKit.Demo.DemoRecord

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>Use this form to manage demo_record records in your database.</:subtitle>
    </.header>

    <.form for={@form} id="demo_record-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:name]} type="text" label="Name" />
      <.input field={@form[:description]} type="textarea" label="Description" />
      <.input field={@form[:count]} type="number" label="Count" />
      <.input field={@form[:rating]} type="number" label="Rating" step="any" />
      <.input field={@form[:price]} type="number" label="Price" step="any" />
      <.input field={@form[:active]} type="checkbox" label="Active" />
      <.input field={@form[:tags]} type="select" multiple label="Tags" options={[{"Option 1", "option1"}, {"Option 2", "option2"}]} />
      <.input field={@form[:published_on]} type="date" label="Published on" />
      <.input field={@form[:alarm_time]} type="time" label="Alarm time" />
      <.input field={@form[:naive_event_at]} type="datetime-local" label="Naive event at" />
      <.input
        field={@form[:status]}
        type="select"
        label="Status"
        prompt="Choose a value"
        options={Ecto.Enum.values(PhoenixStarterKit.Demo.DemoRecord, :status)}
      />
      <footer>
        <.button phx-disable-with="Saving..." variant="primary">Save Demo record</.button>
        <.button navigate={return_path(@return_to, @demo_record)}>Cancel</.button>
      </footer>
    </.form>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    demo_record = Demo.get_demo_record!(id)

    socket
    |> assign(:page_title, "Edit Demo record")
    |> assign(:demo_record, demo_record)
    |> assign(:form, to_form(Demo.change_demo_record(demo_record)))
  end

  defp apply_action(socket, :new, _params) do
    demo_record = %DemoRecord{}

    socket
    |> assign(:page_title, "New Demo record")
    |> assign(:demo_record, demo_record)
    |> assign(:form, to_form(Demo.change_demo_record(demo_record)))
  end

  @impl true
  def handle_event("validate", %{"demo_record" => demo_record_params}, socket) do
    changeset = Demo.change_demo_record(socket.assigns.demo_record, demo_record_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"demo_record" => demo_record_params}, socket) do
    save_demo_record(socket, socket.assigns.live_action, demo_record_params)
  end

  defp save_demo_record(socket, :edit, demo_record_params) do
    case Demo.update_demo_record(socket.assigns.demo_record, demo_record_params) do
      {:ok, demo_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Demo record updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, demo_record))}

        # {:error, %Ecto.Changeset{} = changeset} ->
        #   {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_demo_record(socket, :new, demo_record_params) do
    case Demo.create_demo_record(demo_record_params) do
      {:ok, demo_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Demo record created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, demo_record))}

        # {:error, %Ecto.Changeset{} = changeset} ->
        #   {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _demo_record), do: ~p"/demo/demo_records"
  defp return_path("show", demo_record), do: ~p"/demo/demo_records/#{demo_record}"
end
