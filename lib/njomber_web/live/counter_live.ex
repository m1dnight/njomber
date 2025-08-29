defmodule NjomberWeb.CounterLive do
  use NjomberWeb, :live_view

  def mount(_params, _session, socket) do
    # start with the default keypair
    keypair = %{
      nullifier_key: Application.get_env(:njomber, :nullifier_key),
      nullifier_key_commitment: Application.get_env(:njomber, :nullifier_key)
    }

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:current_keypair, keypair)
      |> assign(
        :keypair_form,
        to_form(%{"nullifier_key" => "", "nullifier_key_commitment" => ""}, as: :keypair)
      )
      |> assign(:json_data, %{})

    {:ok, socket}
  end

  def handle_event("validate-keypair", %{"keypair" => keypair_params}, socket) do
    with {{:ok, _}, _} <- {Base.decode64(keypair_params["nullifier_key"]), :nullifier_key},
         {{:ok, _}, _} <-
           {Base.decode64(keypair_params["nullifier_key_commitment"]), :nullifier_key_commitment} do
      form = to_form(keypair_params, as: :keypair)
      {:noreply, assign(socket, :keypair_form, form)}
    else
      {_, key} ->
        form = to_form(keypair_params, as: :keypair, errors: [{key, {"Invalid hex", []}}])
        {:noreply, assign(socket, :keypair_form, form)}
    end
  end

  # create a new keypair
  def handle_event("create-keypair", _params, socket) do
    {nullifier_key, nullifier_key_commitment} = Njomber.create_keypair()

    keypair = %{
      nullifier_key: Base.encode64(nullifier_key),
      nullifier_key_commitment: Base.encode64(nullifier_key_commitment)
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> put_flash(:info, "New keypair generated successfully!")

    {:noreply, socket}
  end

  # use a default keypair from config
  def handle_event("default-keypair", _params, socket) do
    keypair = %{
      nullifier_key: Application.get_env(:njomber, :nullifier_key),
      nullifier_key_commitment: Application.get_env(:njomber, :nullifier_key)
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> put_flash(:info, "Using default keypair")

    {:noreply, socket}
  end

  # update the keypair based on the user inputs
  def handle_event("update-keypair", %{"keypair" => keypair_params}, socket) do
    keypair = %{
      nullifier_key: keypair_params["nullifier_key"],
      nullifier_key_commitment: keypair_params["nullifier_key_commitment"]
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> put_flash(:info, "Keypair updated!")

    {:noreply, socket}
  end

  # create a new counter object
  def handle_event("create-counter", _params, socket) do
    nullifier = socket.assigns.current_keypair.nullifier_key
    commitment = socket.assigns.current_keypair.nullifier_key_commitment

    {ephemeral_counter, _} =
      Njomber.create_ephemeral_counter(Base.decode64!(nullifier), Base.decode64!(commitment))

    socket =
      socket
      |> update(:json_data, &Map.put(&1, "ephemeral_counter", Jason.encode!(ephemeral_counter, pretty: true)))

    {:noreply, socket}
  end
end
