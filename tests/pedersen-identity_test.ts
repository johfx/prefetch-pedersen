import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Pedersen Identity: User Registration",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('pedersen-identity', 'register-identity', 
        [
          types.principal(user.address),
          types.utf8('Test User'),
          types.uint(1)  // User role
        ],
        deployer.address
      )
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Pedersen Identity: Identity Provider Verification",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const provider = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('pedersen-identity', 'register-provider', 
        [
          types.principal(provider.address),
          types.utf8('Test Provider')
        ],
        deployer.address
      )
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  }
});