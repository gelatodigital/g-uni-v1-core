/* eslint-disable @typescript-eslint/naming-convention */
interface Addresses {
  Gelato: string;
  WETH: string;
  DAI: string;
  USDC: string;
  UniswapV3Factory: string;
  Swapper: string;
  GelatoAdmin: string;
  GUniFactory: string;
  GUniImplementation: string;
}

export const getAddresses = (network: string): Addresses => {
  switch (network) {
    case "mainnet":
      return {
        Gelato: "0x3CACa7b48D0573D793d3b0279b5F0029180E83b6",
        Swapper: "",
        GelatoAdmin: "0x163407FDA1a93941358c1bfda39a868599553b6D",
        WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        UniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        GUniFactory: "0xEA1aFf9dbFfD1580F6b81A3ad3589E66652dB7D9",
        GUniImplementation: "0x68C68FdB1d2dEAf58295008099E061b1749F94cF",
      };
    case "ropsten":
      return {
        Gelato: "0xCc4CcD69D31F9FfDBD3BFfDe49c6aA886DaB98d9",
        Swapper: "0x2E185412E2aF7DC9Ed28359Ea3193EBAd7E929C6",
        GelatoAdmin: "0x4B5BaD436CcA8df3bD39A095b84991fAc9A226F1",
        WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        DAI: "0xaD6D458402F60fD3Bd25163575031ACDce07538D",
        USDC: "0x07865c6e87b9f70255377e024ace6630c1eaa37f",
        UniswapV3Factory: "0x273Edaa13C845F605b5886Dd66C89AB497A6B17b",
        GUniFactory: "0xCe23a1A2B2b18A2fEC300D3DB48f543E9d66BC08",
        GUniImplementation: "0xE6dbcC12016005f3a199BDFF8bee3e3b3C48Cfc5",
      };
    default:
      throw new Error(`No addresses for Network: ${network}`);
  }
};
