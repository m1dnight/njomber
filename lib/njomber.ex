defmodule Njomber do
  @moduledoc """
  Njomber keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Anoma.Util
  alias Anoma.Arm.NullifierKey

  @doc """
  Create a nullifier and commitment for a new user.
  """
  @spec create_keypair :: {binary(), binary()}
  def create_keypair do
    {{nullifier}, {nullifier_commitment}} = NullifierKey.random_pair()
    {Util.binlist2bin(nullifier), Util.binlist2bin(nullifier_commitment)}
  end
end
