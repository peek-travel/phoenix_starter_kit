defmodule PhoenixStarterKitWeb.PlatformGettext do
  @moduledoc """
  Platform-aware Gettext helper with fallback to default domain.

  Uses English strings as msgids (standard gettext convention). Platform-specific
  .po files override specific strings per platform.

  ## Usage

      import PhoenixStarterKitWeb.PlatformGettext

      # Platform is set automatically by plugs/on_mount hooks
      # Then use t/1 with the English string — platform is read from process dictionary
      t("Select Products")
      # => "Select Events" (from acme.po) or "Select Products" (English fallback)

      # With interpolation
      t("Message %{number}", number: 1)
      # => "Event Message 1" (acme) or "Message 1" (default)

  ## How it works

  1. Platform is stored in process dictionary (like Gettext locale)
  2. Try platform-specific domain (e.g., "acme.po")
  3. If no translation found, fall back to "default.po"
  4. If still no translation, return the string as-is (which is already English)
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
  Sets the Gettext locale for the current process from a JWT-provided locale string.
  Overrides any locale previously set (e.g. from browser language detection).
  No-ops when locale is nil or empty — preserving whatever was already set.
  """
  @spec put_locale(String.t() | nil) :: :ok
  def put_locale(locale) when is_binary(locale) and locale != "" do
    Gettext.put_locale(PhoenixStarterKitWeb.Gettext, locale)
    :ok
  end

  def put_locale(_), do: :ok

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

    # When Gettext finds no translation it returns the key with bindings applied.
    # Compute that sentinel value and compare against the platform result:
    # if they match, the platform has no translation and we fall back to default.
    # This avoids the "missing bindings" log warnings that arise from probe-calling
    # dgettext without bindings, while also correctly handling non-English locales
    # (unlike comparing platform_result vs default_result, which breaks when the
    # default domain has a locale translation but the platform domain does not).
    key_interpolated = Enum.reduce(bindings, key, fn {var, val}, str -> String.replace(str, "%{#{var}}", to_string(val)) end)
    platform_result = Gettext.dgettext(PhoenixStarterKitWeb.Gettext, domain, key, bindings)

    if platform_result == key_interpolated do
      Gettext.dgettext(PhoenixStarterKitWeb.Gettext, "default", key, bindings)
    else
      platform_result
    end
  end

  defp platform_to_domain(:peek_pro), do: "peek"
  defp platform_to_domain(platform), do: Atom.to_string(platform)
end
