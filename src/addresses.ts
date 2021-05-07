/* eslint-disable @typescript-eslint/naming-convention */
interface Addresses {
  UniswapV3Factory: string;
  Gelato: string;
  WETH: string;
  DAI: string;
  MetaPoolFactory: string;
  gUNIV3: string;
  Swapper: string;
}

export const getAddresses = (network: string): Addresses => {
  if (network == "rinkeby") {
    return {
      UniswapV3Factory: "0xFeabCc62240297F1e4b238937D68e7516f0918D7",
      Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
      WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
      DAI: "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa",
      MetaPoolFactory: "0xb4Cecd92ADc5CDb0Dd877d6D8203Ac4Eb9db242D",
      gUNIV3: "0xb6b312AE470126D09e2E47a395c2b783dd82366d",
      Swapper: "0x52327D6d94B77AEc83664A4e4758aEA5E34b8574",
    };
  } else if (network == "ropsten") {
    return {
      UniswapV3Factory: "0x273Edaa13C845F605b5886Dd66C89AB497A6B17b",
      Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
      WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
      DAI: "0xaD6D458402F60fD3Bd25163575031ACDce07538D",
      MetaPoolFactory: "0x1c369936cb74193beFE29bF57A426E8C38bc5898",
      gUNIV3: "0x29644532D6C36fCFCAD43F50fe55Fd99f178241c",
      Swapper: "0x2E185412E2aF7DC9Ed28359Ea3193EBAd7E929C6",
    };
  } else {
    throw new Error(`No addresses for Network: ${network}`);
  }
};
