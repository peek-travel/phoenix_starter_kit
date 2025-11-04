defmodule PhoenixStarterKitWeb.Components.LegacyPeekComponents do
  @moduledoc """
  These are components that were from Phoenix 1.7 and modified for theming
  reasons. I'm leaving them around for now to make upgrades easier but my belief
  at the moment is that this is an anti-pattern in favor of daisy ui.
  """
  alias Phoenix.LiveView.JS
  use Phoenix.Component
  use Gettext, backend: PeekAppSDK.UI.Gettext

  import PhoenixStarterKitWeb.CoreComponents

  attr(:current_path, :string, required: true)
  attr(:tabs, :list, required: true)
  attr(:info_icon, :boolean, default: false)
  attr(:truncate_text, :boolean, default: false)

  def tabs(assigns) do
    ~H"""
    <div class="my-4 border-b-2 border-gray-300">
      <div class="flex gap-6">
        <.link
          :for={tab <- @tabs}
          patch={tab.path}
          class={[
            "pb-2 text-base font-medium leading-6 relative",
            tab[:truncate_text] && "truncate",
            @current_path == tab.path && "text-brand -mb-[2px] border-b-2 border-brand",
            @current_path != tab.path && "text-gray-primary"
          ]}
        >
          {tab.name}
          <span :if={tab[:info_icon]} class="ml-0.5">
            <.icon name="hero-information-circle" class="h-5 w-5 mb-1 text-warning" />
          </span>
        </.link>
      </div>
    </div>
    """
  end

  def divider(assigns) do
    ~H"""
    <div class="border-t border-gray-200 my-4"></div>
    """
  end

  attr(:top_caret, :boolean, default: false)

  slot(:inner_block, required: true)

  def tooltip(assigns) do
    ~H"""
    <div class={[
      "absolute left-1/2 -translate-x-1/2 hidden group-hover:flex flex-col items-center w-max max-w-44 z-50",
      if(@top_caret, do: "top-full mt-2", else: "bottom-4 mb-2")
    ]}>
      <%= if @top_caret do %>
        <div class="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-b-[6px] border-b-black"></div>
      <% end %>

      <div class="bg-black text-white text-xs rounded-md p-3 shadow-md">
        {render_slot(@inner_block)}
      </div>
      <%= unless @top_caret do %>
        <div class="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-t-[6px] border-t-black"></div>
      <% end %>
    </div>
    """
  end

  attr(:small, :boolean, default: false)

  def loader(assigns) do
    ~H"""
    <svg
      aria-hidden="true"
      class={[
        "block mx-auto text-gray-200 dark:text-gray-400 animate-spin fill-teal-600",
        if(@small, do: "w-5 h-5 lg:w-6 lg:h-6", else: "w-12 h-12")
      ]}
      viewBox="0 0 100 101"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      data-integration="loader"
    >
      <path
        d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
        fill="currentColor"
      />
      <path
        d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
        fill="currentFill"
      />
    </svg>
    """
  end

  def tag(assigns) do
    ~H"""
    <div class="text-sm rounded-full border border-info px-2 py-1 w-fit text-gray-primary">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:color, :string, default: "success", values: ["success", "warning", "danger", "info"])
  attr(:padded, :boolean, default: false, doc: "whether to pad the alert message for flash X")

  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:subtext)
  slot(:actions)

  def alert(assigns) do
    ~H"""
    <div class={["leading-8 border rounded-md border-l-[5px] p-4", alert_color(@color)]}>
      <div class={["text-gray-primary font-medium", @padded && "pr-4"]}>
        {render_slot(@inner_block)}
      </div>

      <div class={[if(@subtitle != [] || @actions != [], do: "flex flex-col sm:flex-row sm:items-center gap-4")]}>
        <div :if={@subtitle != []} class="text-sm leading-6 text-gray-primary py-2">
          {render_slot(@subtitle)}
        </div>

        <div :if={@actions != []} class="flex gap-2 mt-4">
          {render_slot(@actions)}
        </div>
      </div>

      <div :if={@subtext != []} class="text-sm leading-6 text-gray-primary py-2 font-semibold">
        {render_slot(@subtext)}
      </div>
    </div>
    """
  end

  defp alert_color("success"), do: "border-success"
  defp alert_color("warning"), do: "border-warning"
  defp alert_color("danger"), do: "border-danger"
  defp alert_color("info"), do: "border-info"

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr(:navigate, :any, required: true)
  slot(:inner_block, required: true)

  def back(assigns) do
    ~H"""
    <.link navigate={@navigate} class="text-sm font-semibold leading-6 text-zinc-900 hover:text-gray-primary">
      <.icon name="hero-arrow-left" class="text-brand h-6 w-6" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr(:id, :string, required: true)
  attr(:show, :boolean, default: false)
  attr(:on_cancel, JS, default: %JS{})
  attr(:full_width, :boolean, default: true)
  attr(:full_width_offset, :string, default: "top-0")

  slot(:inner_block, required: true)

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div :if={!@full_width} id={"#{@id}-bg"} class="bg-gray-900/50 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class={["fixed inset-0 overflow-y-auto", @full_width && @full_width_offset]}
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class={["flex items-center justify-center", if(@full_width, do: "min-h-screen", else: "min-h-full")]}>
          <div class={["w-full", if(@full_width, do: "h-screen", else: "max-w-3xl p-4 sm:p-6 lg:py-8")]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class={[
                "shadow-zinc-700/10 ring-zinc-700/10 relative hidden bg-white transition",
                if(@full_width, do: "py-2.5 px-4", else: "rounded-xl p-10 shadow-lg ring-1 transition")
              ]}
            >
              <div class={["absolute", if(@full_width, do: "top-0 left-0", else: "top-6 right-5")]}>
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class={["flex-none p-3", if(!@full_width, do: "-m-3")]}
                  aria-label={gettext("close")}
                >
                  <.icon name={if(@full_width, do: "hero-arrow-left", else: "hero-x-mark-solid")} class="h-6 w-6 text-brand" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def footer(assigns) do
    ~H"""
    <div class="bg-background-secondary p-4 border-t border-gray-200">
      <div class="flex items-center gap-4 max-w-[600px] mx-auto sm:px-2">
        <img :if={@image_path} src={@image_path} class="w-32" />
      </div>
    </div>
    """
  end

  attr(:background_color, :string,
    default: "transparent",
    values: ["transparent", "primary", "secondary", "gradient"]
  )

  attr(:text_size, :string, default: "medium", values: ["small", "medium", "large"])

  attr(:text_color, :string,
    default: "gray-primary",
    values: ["gray-primary", "dark-gray", "black"]
  )

  attr(:bold, :boolean, default: false)
  attr(:semibold, :boolean, default: false)
  attr(:tooltip, :string, default: nil)
  attr(:top_caret, :boolean, default: false)

  slot(:inner_block, required: true)
  slot(:actions)

  def message(assigns) do
    ~H"""
    <div class="relative">
      <div class={[
        "leading-6",
        @actions != [] && "flex items-center justify-between gap-6",
        @bold && "font-semibold",
        @semibold && "font-medium",
        background_color(@background_color),
        message_text_size(@text_size),
        message_text_color(@text_color)
      ]}>
        <div class={@tooltip && "flex items-center gap-2"}>
          <p>{render_slot(@inner_block)}</p>
          <div :if={@tooltip} class="group relative">
            <.icon name="hero-information-circle" class="h-4 w-4 mb-1 text-gray-primary group-hover:text-gray-700" />
            <.tooltip top_caret={@top_caret}>{@tooltip}</.tooltip>
          </div>
        </div>
        <div class="flex-none">{render_slot(@actions)}</div>
      </div>
    </div>
    """
  end

  defp message_text_color(text_color) do
    case text_color do
      "gray-primary" -> "text-gray-primary"
      "dark-gray" -> "text-gray-800"
      "black" -> "text-black"
    end
  end

  defp message_text_size(text_size) do
    case text_size do
      "small" -> "text-sm"
      "medium" -> "text-base"
      "large" -> "text-lg"
    end
  end

  defp background_color(background_color) do
    case background_color do
      "transparent" -> "bg-transparent"
      "primary" -> "bg-background-primary p-4 rounded-md"
      "secondary" -> "bg-background-secondary p-4 rounded-md"
      "gradient" -> "bg-gradient-to-r from-pale-green to-pale-blue p-4 rounded-md"
    end
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr(:type, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled form name value))

  attr(:button_type, :string,
    default: "primary",
    values: ["primary", "secondary", "info", "danger"]
  )

  attr(:disabled, :boolean, default: false)
  attr(:id, :string, default: nil)

  slot(:icon)

  slot(:inner_block, required: true)

  def peek_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-md py-2 px-3 font-medium text-sm leading-6 whitespace-nowrap",
        if(@disabled, do: "opacity-50 cursor-not-allowed pointer-events-none"),
        button_classes(@button_type),
        @class
      ]}
      disabled={@disabled}
      id={@id}
      {@rest}
    >
      <span :if={@icon} class="h-4 w-4">{render_slot(@icon)}</span>
      <span>{render_slot(@inner_block)}</span>
    </button>
    """
  end

  defp button_classes(button_type) do
    case button_type do
      "primary" ->
        "bg-brand hover:bg-brand-secondary text-white active:text-white/80"

      "secondary" ->
        "bg-background-primary hover:bg-background-secondary text-brand"

      "info" ->
        "bg-white text-gray-primary border border-gray-200 hover:bg-gray-100/20 hover:shadow-md"

      "danger" ->
        "bg-white hover:bg-gray-100/20 hover:shadow-md text-danger border border-danger"
    end
  end

  @doc """
  Renders a header with title.
  """
  attr(:class, :string, default: nil)
  attr(:backlink, :string, default: nil)
  attr(:show_divider, :boolean, default: true)
  attr(:text_size, :string, default: "large", values: ["small", "medium", "large"])
  attr(:small, :boolean, default: false)
  attr(:medium, :boolean, default: false)

  attr(:full_width, :boolean,
    default: false,
    doc: "whether to pad the header for the back button for full width `modal`"
  )

  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def peek_header(assigns) do
    ~H"""
    <header>
      <div class="flex items-center gap-4">
        <.back :if={@backlink} navigate={@backlink}></.back>

        <h1 class={["font-medium leading-8 text-zinc-800", header_text_size(@text_size), @full_width && "ml-8"]}>
          {render_slot(@inner_block)}
        </h1>
        <div class="flex-none ml-auto">{render_slot(@actions)}</div>
      </div>

      <div :if={@show_divider}>
        <.divider />
      </div>
      <p :if={@subtitle != []} class={["text-sm leading-6 text-gray-primary bg-background-secondary p-2 rounded-md", !@show_divider && "mt-4"]}>
        {render_slot(@subtitle)}
      </p>
    </header>
    """
  end

  defp header_text_size(text_size) do
    case text_size do
      "small" -> "text-base"
      "medium" -> "text-xl"
      "large" -> "text-2xl"
    end
  end
end
