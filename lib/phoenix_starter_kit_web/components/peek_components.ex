defmodule PhoenixStarterKitWeb.Components.PeekComponents do
  @moduledoc """
  These are components that were from Phoenix 1.7 and modified for theming
  reasons. I'm leaving them around for now to make upgrades easier but my belief
  at the moment is that this is an anti-pattern in favor of daisy ui.
  """
  use Phoenix.Component
  use Gettext, backend: PeekAppSDK.UI.Gettext
  import PhoenixStarterKitWeb.CoreComponents

  def divider(assigns) do
    ~H"""
    <div class="border-t border-gray-200 my-4"></div>
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
        </div>
        <div class="flex-none">{render_slot(@actions)}</div>
      </div>
    </div>
    """
  end

  defp message_text_color(text_color),
    do:
      Map.fetch!(
        %{
          "gray-primary" => "text-gray-primary",
          "dark-gray" => "text-gray-800",
          "black" => "text-black"
        },
        text_color
      )

  defp message_text_size(text_size) do
    Map.fetch!(
      %{
        "small" => "text-sm",
        "medium" => "text-base",
        "large" => "text-lg"
      },
      text_size
    )
  end

  defp background_color(background_color) do
    Map.fetch!(
      %{
        "transparent" => "bg-transparent",
        "primary" => "bg-background-primary p-4 rounded-md",
        "secondary" => "bg-background-secondary p-4 rounded-md",
        "gradient" => "bg-gradient-to-r from-pale-green to-pale-blue p-4 rounded-md"
      },
      background_color
    )
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
    </div>
    """
  end

  defp alert_color(color) do
    Map.fetch!(
      %{
        "success" => "border-success",
        "warning" => "border-warning",
        "danger" => "border-danger",
        "info" => "border-info"
      },
      color
    )
  end

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
end
