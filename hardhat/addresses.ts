interface addresses {
  UniswapV3Factory: string;
  Gelato: string;
  WETH: string;
  DAI: string;
  MetaPoolFactory: string;
  gUNIV3: string;
  Swapper: string;
}

export const getAddresses = (network: string) => {
  let addrs: addresses = {
    UniswapV3Factory: "",
    Gelato: "",
    WETH: "",
    DAI: "",
    MetaPoolFactory: "",
    gUNIV3: "",
    Swapper: "",
  };
  if (network == "rinkeby") {
    addrs = {
      UniswapV3Factory: "0xFeabCc62240297F1e4b238937D68e7516f0918D7",
      Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
      WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
      DAI: "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa",
      MetaPoolFactory: "0xb4Cecd92ADc5CDb0Dd877d6D8203Ac4Eb9db242D",
      gUNIV3: "0xb6b312AE470126D09e2E47a395c2b783dd82366d",
      Swapper: "0x52327D6d94B77AEc83664A4e4758aEA5E34b8574",
    };
  } else if (network == "ropsten") {
    addrs = {
      UniswapV3Factory: "0x273Edaa13C845F605b5886Dd66C89AB497A6B17b",
      Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
      WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
      DAI: "0xaD6D458402F60fD3Bd25163575031ACDce07538D",
      MetaPoolFactory: "0x1E1beC806ca7d0b76B014a4e714F13eF9e563313",
      gUNIV3: "0xd26133af3a606480916BEbEA9fFE94Cbeb4D05c2",
      Swapper: "0x2E185412E2aF7DC9Ed28359Ea3193EBAd7E929C6",
    };
  }

  return addrs;
};
