defmodule NjomberWeb.CounterLive do
  use NjomberWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:current_keypair, nil)
      |> assign(
        :keypair_form,
        to_form(%{"nullifier_key" => "", "nullifier_key_commitment" => ""}, as: :keypair)
      )

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
      nullifier_key_commitment: Application.get_env(:njomber, :nullifier_key),
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> put_flash(:info, "Using default keypair")

    {:noreply, socket}
  end

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

  # change the keypair based on the inputs
  def handle_event("set_custom_keypair", %{"keypair" => keypair_params}, socket) do
    nullifier_key = String.trim(keypair_params["nullifier_key"] || "")
    nullifier_key_commitment = String.trim(keypair_params["nullifier_key_commitment"] || "")

    keypair = %{
      nullifier_key: nullifier_key,
      nullifier_key_commitment: nullifier_key_commitment,
      created_at: DateTime.utc_now(),
      custom: true
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> assign(
        :keypair_form,
        to_form(%{"nullifier_key" => "", "nullifier_key_commitment" => ""}, as: :keypair)
      )
      |> put_flash(:info, "Custom keypair set successfully!")

    {:noreply, socket}
  end

  def handle_event("clear_keypair", _params, socket) do
    socket =
      socket
      |> assign(:current_keypair, nil)
      |> put_flash(:info, "Keypair cleared")

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>

    <!-- Keypair -->

      <div id="keypair-section">
        <h2 class="text-xl font-semibold flex items-center pb-5">
          <.icon name="hero-key" class="w-5 h-5 mr-2" /> Keypair
        </h2>

        <div class="flex flex-col">
          <div>
            <.button phx-click="create-keypair">
              Generate
            </.button>
            <.button phx-click="default-keypair">
              Default
            </.button>
          </div>
        </div>
      </div>

    <!-- Input own keys -->
      <div>
        <.form
          for={@keypair_form}
          id="keypair-form"
          phx-change="validate-keypair"
          phx-submit="update-keypair"
        >
          <label>
            Nullifier Key
          </label>
          <.input field={@keypair_form[:nullifier_key]} type="text" />

          <label>
            Nullifier Key Commitment
          </label>
          <.input field={@keypair_form[:nullifier_key_commitment]} type="text" />

          <.button type="submit">
            Submit
          </.button>
        </.form>
      </div>

    <!-- Current keys in use -->
      <div :if={@current_keypair} id="generate-keypair-output">
        <label>
          Nullifier Key
        </label>
        <.input name="nullifier_key" type="text" value={@current_keypair.nullifier_key} />

        <label>
          Nullifier Key Commitment
        </label>
        <.input
          name="nullifier_key_commitment"
          type="text"
          value={@current_keypair.nullifier_key_commitment}
        />
      </div>


    <!-- Create counter -->
      <div id="generate-counter" class="content-around">
          <.button>
            Initialize Counter
          </.button>
      </div>
    </Layouts.app>
    """
  end
end
