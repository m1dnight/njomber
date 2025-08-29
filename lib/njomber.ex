defmodule Njomber do
  @moduledoc """
  Njomber keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def create_keypair do
    {{nullifier}, {nullifier_commitment}} = Anoma.Arm.NullifierKey.random_pair()
    {Anoma.Util.binlist2bin(nullifier), Anoma.Util.binlist2bin(nullifier_commitment)}
  end
end
