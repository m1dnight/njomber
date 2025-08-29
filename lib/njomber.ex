defmodule Njomber do
  @moduledoc """
  Njomber keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Anoma.Util
  alias Anoma.Arm.NullifierKey
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

  @doc """
  Create a nullifier and commitment for a new user.
  """
  @spec create_keypair :: {binary(), binary()}
  def create_keypair do
    {{nullifier}, {nullifier_commitment}} = NullifierKey.random_pair()
    {Util.binlist2bin(nullifier), Util.binlist2bin(nullifier_commitment)}
  end

  @doc """
  Create a new ephemeral counter.

  A counter is represented by its owner, and a unique label.
  """
  @spec create_ephemeral_counter(NullifierKey.t(), NullifierKeyCommitment.t()) :: Resource.t()
  def create_ephemeral_counter(key, commitment) do
    # the counter value is little endian encoded, padded to 32 bytes.
    counter_value =
      0
      |> :binary.encode_unsigned(:little)
      |> Util.pad_bitstring(32)
      |> Util.bin2binlist()

    # Create a counter resource
    resource = %Resource{
      logic_ref: Counter.counter_logic_ref(),
      label_ref: randombinlist(32),
      quantity: 1,
      value_ref: counter_value,
      is_ephemeral: true,
      nonce: Util.randombinlist(32),
      nk_commitment: commitment
    }

    {resource, key}
  end
end
