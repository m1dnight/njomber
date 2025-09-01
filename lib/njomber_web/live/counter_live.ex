defmodule NjomberWeb.CounterLive do
  use NjomberWeb, :live_view

  alias Anoma.Arm
  alias Anoma.Arm.ComplianceUnit
  alias Anoma.Arm.ComplianceWitness
  alias Anoma.Arm.ComplianceInstance
  alias Anoma.Arm.MerklePath
  alias Anoma.Arm.NullifierKey
  alias Anoma.Arm.Transaction
  alias Anoma.Arm.DeltaWitness
  alias Anoma.Arm.Action
  alias Anoma.Arm.Resource
  alias Anoma.Examples.Counter
  alias Anoma.Examples.Counter.CounterLogic
  alias Anoma.Examples.Counter.CounterWitness
  alias Anoma.Arm.MerkleTree
  alias Anoma.Util

  def mount(_params, _session, socket) do
    # start with the default keypair
    key = {Anoma.Util.bin2binlist(Base.decode64!(Application.get_env(:njomber, :nullifier_key)))}

    commitment =
      {Anoma.Util.bin2binlist(
         Base.decode64!(Application.get_env(:njomber, :nullifier_key_commitment))
       )}

    keypair = %{
      nullifier_key: key,
      nullifier_key_commitment: commitment
    }

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:message, nil)
      |> assign(:current_keypair, keypair)
      |> assign(
        :keypair_form,
        to_form(%{"nullifier_key" => "", "nullifier_key_commitment" => ""}, as: :keypair)
      )
      |> assign(:json_data, %{})
      |> assign(:selected_tab, nil)

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
      nullifier_key: nullifier_key,
      nullifier_key_commitment: nullifier_key_commitment
    }

    socket =
      socket
      |> assign(:current_keypair, keypair)
      |> put_flash(:info, "New keypair generated successfully!")

    {:noreply, socket}
  end

  # use a default keypair from config
  def handle_event("default-keypair", _params, socket) do
    key = {Anoma.Util.bin2binlist(Base.decode64!(Application.get_env(:njomber, :nullifier_key)))}

    commitment =
      {Anoma.Util.bin2binlist(
         Base.decode64!(Application.get_env(:njomber, :nullifier_key_commitment))
       )}

    keypair = %{
      nullifier_key: key,
      nullifier_key_commitment: commitment
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

  def handle_event("select-tab", %{"tab" => tab_name}, socket) do
    {:noreply, assign(socket, :selected_tab, tab_name)}
  end

  # create a new counter object
  def handle_event("create-counter", _params, socket) do
    nullifier = socket.assigns.current_keypair.nullifier_key
    commitment = socket.assigns.current_keypair.nullifier_key_commitment

    this = self()

    Task.async(fn ->
      generate_ephemeral_counter(nullifier, commitment, this)
    end)

    {:noreply, socket}
  end

  def handle_info({:message, msg}, socket) do
    {:noreply, assign(socket, :message, msg)}
  end

  def handle_info({ref, _}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, socket}
  end

  def handle_info({label, value}, socket) do
    {:noreply, update(socket, :json_data, &Map.put(&1, "#{label}", inspect(value, pretty: true)))}
  end

  defp generate_ephemeral_counter(nullifier, commitment, listener) do
    # ---------------------------------------------------------------------------
    # create counter

    send(listener, {:message, "Creating ephemeral counter"})
    # create the ephemeral counter
    {ephemeral_counter, ephemeral_counter_nf} = Njomber.create_ephemeral_counter()
    send(listener, {:ephemeral_counter, ephemeral_counter})

    # ---------------------------------------------------------------------------
    # create counter

    send(listener, {:message, "Creating new counter"})

    created_counter =
      Njomber.create_new_counter(nullifier, commitment, ephemeral_counter, ephemeral_counter_nf)

    send(listener, {:created_counter, created_counter})

    # ---------------------------------------------------------------------------
    # create compliance proof

    send(listener, {:message, "Creating compliance proofs"})

    {compliance_unit, rcv} =
      Njomber.generate_compliance_proof(
        ephemeral_counter,
        ephemeral_counter_nf,
        MerklePath.default(),
        created_counter
      )

    send(listener, {:compliance_unit, compliance_unit})

    # ---------------------------------------------------------------------------
    # create logic proofs

    send(listener, {:message, "Creating logic proofs"})

    {consumed_proof, created_proof} =
      Njomber.generate_logic_proofs(ephemeral_counter, ephemeral_counter_nf, created_counter)

    consumed_proof = Anoma.Arm.convert(consumed_proof)
    send(listener, {:consumed_proof, consumed_proof})

    created_proof = Anoma.Arm.convert(created_proof)
    send(listener, {:created_proof, created_proof})

    # ---------------------------------------------------------------------------
    # create action

    send(listener, {:message, "Creating action"})

    # create an action for this transaction
    action = %Action{
      compliance_units: [compliance_unit],
      logic_verifier_inputs: [consumed_proof, created_proof]
    }

    send(listener, {:action, action})

    delta_witness = %DeltaWitness{signing_key: Anoma.Util.binlist2bin(rcv)}
    send(listener, {:delta_witness, delta_witness})

    # ---------------------------------------------------------------------------
    # create transaction

    send(listener, {:message, "Creating transaction delta proof"})

    transaction = %Transaction{
      actions: [action],
      delta_proof: {:witness, delta_witness}
    }

    send(listener, {:transaction, transaction})

    # generate the delta proof for the transaction
    transaction = Transaction.generate_delta_proof(transaction)
    send(listener, {:transaction, transaction})

    send(listener, {:message, "Done"})
  end
end
