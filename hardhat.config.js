/** @type import('hardhat/config').HardhatUserConfig */

// Resolves imports with the Foundry remappings (`forge remappings`: CMTAT/, OZ/, @openzeppelin/...),
// so Hardhat compiles exactly the sources Foundry compiles. Requires `forge` on the PATH.
require('@nomicfoundation/hardhat-foundry')

module.exports = {
  // Same compiler settings as foundry.toml; keep the two in sync.
  solidity: {
    version: '0.8.33',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: 'prague'
    }
  },
  paths: {
    // Production contracts only: the tests and scripts are Foundry (.t.sol / .s.sol).
    sources: './src',
    // Separate from Foundry's cache/ and out/.
    cache: './cache_hardhat',
    artifacts: './artifacts'
  }
}
