const getPermitSignature = async (signer, token, spender, value, deadline) => {
  const [nonce, name, version, chainId] = await Promise.all([
    token.nonces(signer.address),
    token.name(),
    "1",
    31337,
  ]);

  const result = await signer.signTypedData(
    {
      name,
      version,
      chainId,
      verifyingContract: token.address,
    },
    {
      Permit: [
        {
          name: "owner",
          type: "address",
        },
        {
          name: "spender",
          type: "address",
        },
        {
          name: "value",
          type: "uint256",
        },
        {
          name: "nonce",
          type: "uint256",
        },
        {
          name: "deadline",
          type: "uint256",
        },
      ],
    },
    {
      owner: signer.address,
      spender,
      value,
      nonce,
      deadline,
    }
  );

  return result;
};

module.exports = {
  getPermitSignature,
};
