defmodule PhoenixStarterKitWeb.PlatformGettextTest do
  use ExUnit.Case, async: false

  alias PhoenixStarterKitWeb.PlatformGettext

  describe "put_platform/1 and get_platform/0" do
    test "stores and retrieves platform from process dictionary" do
      PlatformGettext.put_platform(:acme)
      assert PlatformGettext.get_platform() == :acme
    end

    test "returns :default when no platform is set" do
      Process.delete({PlatformGettext, :platform})
      assert PlatformGettext.get_platform() == :default
    end
  end

  describe "t/1" do
    test "uses platform from process dictionary" do
      PlatformGettext.put_platform(:acme)
      # acme.po has "Save" -> "Submit"
      assert PlatformGettext.t("Save") == "Submit"
    end

    test "falls back to default domain when platform has no override" do
      PlatformGettext.put_platform(:peek)
      # peek has no .po file, falls back to default.po
      assert PlatformGettext.t("Save") == "Save"
    end

    test "uses default platform when none set" do
      Process.delete({PlatformGettext, :platform})
      assert PlatformGettext.t("Cancel") == "Cancel"
    end

    test "normalizes peek_pro to peek domain" do
      PlatformGettext.put_platform(:peek_pro)
      # peek_pro should use peek domain (no override), falls back to default
      assert PlatformGettext.t("Cancel") == "Cancel"
    end

    test "returns string as-is when no translation exists in any domain" do
      PlatformGettext.put_platform(:acme)
      assert PlatformGettext.t("This string has no translation") == "This string has no translation"
    end
  end

  describe "t/2 with bindings" do
    test "uses platform from process dictionary with bindings" do
      PlatformGettext.put_platform(:acme)
      # acme.po has "Saved successfully" -> "Event saved successfully"
      assert PlatformGettext.t("Saved successfully", []) == "Event saved successfully"
    end

    test "falls back to default domain with bindings when platform has no override" do
      PlatformGettext.put_platform(:peek)
      assert PlatformGettext.t("Saved successfully", []) == "Saved successfully"
    end

    test "normalizes peek_pro to peek domain with bindings" do
      PlatformGettext.put_platform(:peek_pro)
      assert PlatformGettext.t("Saved successfully", []) == "Saved successfully"
    end

    test "returns string with interpolated bindings when no translation exists" do
      PlatformGettext.put_platform(:peek)
      result = PlatformGettext.t("No translation for %{value}", value: "thing")
      assert result == "No translation for thing"
    end
  end
end
