defmodule PhoenixStarterKitWeb.PlatformGettext do
  @moduledoc """
  Platform-aware Gettext helper with fallback to default domain.

  Uses simple keys like "campaigns.select_products" that map to translations.
  Platform-specific .po files are optional - only create them when you need overrides.

  ## Usage

      import PhoenixStarterKitWeb.PlatformGettext

      # Platform is set automatically by plugs/on_mount hooks
      # Then use simple t/1 calls - platform is read from process dictionary
      t("campaigns.select_products")
      # => "Select Events" (from acme.po) or "Select Products" (from default.po)

      # With interpolation
      t("campaigns.message_number", number: 1)
      # => "Message 1"

  ## How it works

  1. Platform is stored in process dictionary (like Gettext locale)
  2. Try platform-specific domain (e.g., "acme.po")
  3. If no translation found, fall back to "default.po"
  4. If still no translation, return the key
  """

  @platform_key {__MODULE__, :platform}

  @doc """
  Stores the platform in the process dictionary for the current request.
  """
  @spec put_platform(atom()) :: atom() | nil
  def put_platform(platform) when is_atom(platform) do
    Process.put(@platform_key, platform)
  end

  @doc """
  Gets the platform from the process dictionary. Returns :default if not set.
  """
  @spec get_platform() :: atom()
  def get_platform do
    Process.get(@platform_key) || :default
  end

  @doc """
  Translates a key using the platform stored in process dictionary.
  """
  @spec t(String.t()) :: String.t()
  def t(key) when is_binary(key) do
    platform = get_platform()
    domain = platform_to_domain(platform)
    result = Gettext.dgettext(PhoenixStarterKitWeb.Gettext, domain, key)

    if result == key do
      Gettext.dgettext(PhoenixStarterKitWeb.Gettext, "default", key)
    else
      result
    end
  end

  @doc """
  Translates a key with interpolation bindings.
  """
  @spec t(String.t(), keyword()) :: String.t()
  def t(key, bindings) when is_binary(key) and is_list(bindings) do
    platform = get_platform()
    domain = platform_to_domain(platform)
    raw_result = Gettext.dgettext(PhoenixStarterKitWeb.Gettext, domain, key)

    if raw_result == key do
      Gettext.dgettext(PhoenixStarterKitWeb.Gettext, "default", key, bindings)
    else
      Gettext.dgettext(PhoenixStarterKitWeb.Gettext, domain, key, bindings)
    end
  end

  defp platform_to_domain(:peek_pro), do: "peek"
  defp platform_to_domain(platform), do: Atom.to_string(platform)
end
