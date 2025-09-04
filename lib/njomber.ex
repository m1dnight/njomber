defmodule Njomber do
  @moduledoc """
  Njomber keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

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

  import Anoma.Util

  def test() do
    a = default_keypair()
    b = default_keypair()

    # create an ephemeral counter
    eph_counter = create_ephemeral_counter(a)

    # create a new counter
    created = create_new_counter(a, eph_counter, b)

    {compliance_unit, rcv} =
      generate_compliance_proof(
        eph_counter,
        b.nullifier_key,
        MerklePath.default(),
        created
      )

    {consumed_proof, created_proof} =
      Njomber.generate_logic_proofs(eph_counter, b.nullifier_key, created)

    consumed_proof = Arm.convert(consumed_proof)
    created_proof = Arm.convert(created_proof)

    # create an action for this transaction
    action = %Action{
      compliance_units: [compliance_unit],
      logic_verifier_inputs: [consumed_proof, created_proof]
    }

    delta_witness = %DeltaWitness{signing_key: Anoma.Util.binlist2bin(rcv)}

    transaction = %Transaction{
      actions: [action],
      delta_proof: {:witness, delta_witness}
    }

    transaction = Transaction.generate_delta_proof(transaction)
  end

  @spec default_keypair :: map()
  def default_keypair do
    key = Application.get_env(:njomber, :nullifier_key)
    commitment = Application.get_env(:njomber, :nullifier_key_commitment)

    %{
      nullifier_key: key,
      nullifier_key_commitment: commitment
    }
  end

  @doc """
  Create a nullifier and commitment for a new user.
  """
  @spec create_keypair :: map()
  def create_keypair do
    {key, commitment} = NullifierKey.random_pair()

    %{
      nullifier_key: key,
      nullifier_key_commitment: commitment
    }
  end

  @doc """
  Create a new ephemeral counter.

  A counter is represented by its owner, and a unique label.
  """
  # @spec create_ephemeral_counter() :: Resource.t()
  def create_ephemeral_counter(keypair) do
    # the counter value is little endian encoded, padded to 32 bytes.
    counter_value =
      0
      |> :binary.encode_unsigned(:little)
      |> Util.pad_bitstring(32)
      |> Util.bin2binlist()

    # Create a counter resource
    %Resource{
      logic_ref: Counter.counter_logic_ref(),
      label_ref: randombinlist(32),
      quantity: 1,
      value_ref: counter_value,
      is_ephemeral: true,
      nonce: Util.randombinlist(32),
      nk_commitment: keypair.nullifier_key_commitment
    }
  end

  @doc """
  Given an ephemeral counter, creates a new counter to be created.

  The ephemeral counter serves as the resource we are consuming, in order to
  creeate the new counter.
  """
  def create_new_counter(keypair_a, ephemeral_counter, keypair_b) do
    # the counter value is little endian encoded, padded to 32 bytes.
    counter_value =
      1
      |> :binary.encode_unsigned(:little)
      |> Util.pad_bitstring(32)
      |> Util.bin2binlist()
      |> Enum.reverse()

    resource = %{
      ephemeral_counter
      | is_ephemeral: false,
        rand_seed: Util.randombinlist(32),
        nonce: Resource.nullifier(ephemeral_counter, keypair_a.nullifier_key),
        value_ref: counter_value,
        nk_commitment: keypair_b.nullifier_key_commitment
    }

    resource
  end

  def increment_counter(old_counter, old_nf_key) do
    # the counter value is little endian encoded, padded to 32 bytes.
    counter_value =
      2
      |> :binary.encode_unsigned(:little)
      |> Util.pad_bitstring(32)
      |> Util.bin2binlist()
      |> Enum.reverse()

    resource = %{
      old_counter
      | is_ephemeral: false,
        rand_seed: Util.randombinlist(32),
        nonce: Resource.nullifier(old_counter, old_nf_key),
        value_ref: counter_value
    }

    resource
  end

  def create_increment_tx(old_counter, old_nf_key) do
    new_counter = increment_counter(old_counter, old_nf_key)

    generate_compliance_proof(old_counter, old_nf_key, MerklePath.default(), new_counter)
  end

  @doc """
  Generate a compliance proof for two resources.
  """
  @spec generate_compliance_proof(Resource.t(), NullifierKey.t(), MerklePath.t(), Resource.t()) ::
          {ComplianceUnit.t(), [byte()]}
  def generate_compliance_proof(consumed, consumed_nf, merkle_path, created) do
    compliance_witness =
      ComplianceWitness.from_resources_with_path(consumed, consumed_nf, merkle_path, created)

    compliance_unit = Arm.prove(compliance_witness)

    {compliance_unit, compliance_witness.rcv}
  end

  @doc """
  Generate the logic proofs for the given resources.
  """
  @spec generate_logic_proofs(Resource.t(), NullifierKey.t(), Resource.t()) ::
          {LogicProof.t(), LogicProof.t()}
  def generate_logic_proofs(consumed, consumed_nf, created) do
    nullifier = Resource.nullifier(consumed, consumed_nf)
    commitment = Resource.commitment(created)

    action_tree =
      MerkleTree.new([
        binlist2vec32(nullifier),
        binlist2vec32(commitment)
      ])

    # create the path of the nullifier and commitments in the action tree.
    consumed_resource_path = MerkleTree.path_of(action_tree, binlist2vec32(nullifier))
    created_resource_path = MerkleTree.path_of(action_tree, binlist2vec32(commitment))

    # counter logic for consumed resource
    consumed_counter_logic = %CounterLogic{
      witness: %CounterWitness{
        is_consumed: true,
        old_counter: consumed,
        old_counter_existence_path: consumed_resource_path,
        nf_key: consumed_nf,
        new_counter: created,
        new_counter_existence_path: created_resource_path
      }
    }

    # generate the proof for the consumed counter
    consumed_logic_proof = Counter.prove_counter_logic(consumed_counter_logic)

    # create a proof for the created counter
    created_counter_logic = %CounterLogic{
      witness: %{consumed_counter_logic.witness | is_consumed: false}
    }

    created_logic_proof = Counter.prove_counter_logic(created_counter_logic)

    {consumed_logic_proof, created_logic_proof}
  end
end
