import {expect, use} from 'chai';
import {Contract} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import Exchange from '../build/Exchange.json';

use(solidity);

describe('Exchange', () => {
  const [wallet, walletTo] = new MockProvider().getWallets();
  let exchange: Contract;

  beforeEach(async () => {
    exchange = await deployContract(wallet, Exchange, [1000]);
  });

  it('Assigns initial balance', async () => {
    expect(await exchange.balanceOf(wallet.address)).to.equal(1000);
  });

  it('Transfer adds amount to destination account', async () => {
    await exchange.transfer(walletTo.address, 7);
    expect(await exchange.balanceOf(walletTo.address)).to.equal(7);
  });

  it('Transfer emits event', async () => {
    await expect(exchange.transfer(walletTo.address, 7))
      .to.emit(exchange, 'Transfer')
      .withArgs(wallet.address, walletTo.address, 7);
  });

  it('Can not transfer above the amount', async () => {
    await expect(exchange.transfer(walletTo.address, 1007)).to.be.reverted;
  });

  it('Can not transfer from empty account', async () => {
    const exchangeFromOtherWallet = exchange.connect(walletTo);
    await expect(exchangeFromOtherWallet.transfer(wallet.address, 1))
      .to.be.reverted;
  });

  it('Calls totalSupply on Basicexchange contract', async () => {
    await exchange.totalSupply();
    expect('totalSupply').to.be.calledOnContract(exchange);
  });

  it('Calls balanceOf with sender address on Basicexchange contract', async () => {
    await exchange.balanceOf(wallet.address);
    expect('balanceOf').to.be.calledOnContractWith(exchange, [wallet.address]);
  });
});