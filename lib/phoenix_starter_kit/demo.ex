defmodule PhoenixStarterKit.Demo do
  @moduledoc """
  Demo Context

  This is here to power the demo section which serves a few purposes:

  1. Ensure things work in CI; bumping a dep, etc.
  2. Let engineers new to phoenix see some patterns
  3. Teach AI (Augment) some decent patterns.

  This was 100% generated w/ a command:
  `mix phx.gen.live Demo DemoRecord demo_records name:string etc etc`

  It is strongly recommended when building new features that the above command
  is used to scaffold out the "CRUD", the generated forms can then be updated to
  match the needs of the comps but the "hard part" of wiring up the fetching and
  saving of the data will be done w/ phoenix best practices.

  If some functionality is not needed, that's fine, just delete the unused
  context functions (or leave them as they are scaffolded with test coverage)
  """

  import Ecto.Query, warn: false
  alias PhoenixStarterKit.Repo

  alias PhoenixStarterKit.Demo.DemoRecord

  @doc """
  Returns the list of demo_record.

  ## Examples

      iex> list_demo_records()
      [%DemoRecord{}, ...]

  """
  def list_demo_records do
    Repo.all(DemoRecord)
  end

  @doc """
  Gets a single demo_record.

  Raises `Ecto.NoResultsError` if the Demo records does not exist.

  ## Examples

      iex> get_demo_record!(123)
      %DemoRecord{}

      iex> get_demo_record!(456)
      ** (Ecto.NoResultsError)

  """
  def get_demo_record!(id), do: Repo.get!(DemoRecord, id)

  @doc """
  Creates a demo_record.

  ## Examples

      iex> create_demo_record(%{field: value})
      {:ok, %DemoRecord{}}

      iex> create_demo_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_demo_record(attrs \\ %{}) do
    %DemoRecord{}
    |> DemoRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a demo_record.

  ## Examples

      iex> update_demo_record(demo_record, %{field: new_value})
      {:ok, %DemoRecord{}}

      iex> update_demo_record(demo_record, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_demo_record(%DemoRecord{} = demo_record, attrs) do
    demo_record
    |> DemoRecord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a demo_record.

  ## Examples

      iex> delete_demo_record(demo_record)
      {:ok, %DemoRecord{}}

      iex> delete_demo_record(demo_record)
      {:error, %Ecto.Changeset{}}

  """
  def delete_demo_record(%DemoRecord{} = demo_record) do
    Repo.delete(demo_record)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking demo_record changes.

  ## Examples

      iex> change_demo_record(demo_record)
      %Ecto.Changeset{data: %DemoRecord{}}

  """
  def change_demo_record(%DemoRecord{} = demo_record, attrs \\ %{}) do
    DemoRecord.changeset(demo_record, attrs)
  end
end
