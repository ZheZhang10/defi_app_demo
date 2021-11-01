from brownie import exceptions
from brownie import network
from scripts.deploy import deploy_token_and_farm
from scripts.helpful_scripts import (
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    get_account,
    get_contract,
    INITIAL_PRICE_FEED_VALUE
)
import pytest


def test_setPriceFeedContract():
    # test if it gets correct pricefeed contract
    # test if non_owner can call this function
    # arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Not in local environment")
    account = get_account()
    non_owner = get_account(index=1)
    token_farm, dapp_token = deploy_token_and_farm()
    # act
    price_feed_address = get_contract("dai_usd_price_feed")
    token_farm.setPriceFeedContract(
        dapp_token.address, price_feed_address, {"from": account}
    )
    # assert
    assert token_farm.tokenPriceFeedMapping(dapp_token.address) == price_feed_address
    with pytest.raises(exceptions.VirtualMachineError):
        token_farm.setPriceFeedContract(
            dapp_token.address, price_feed_address, {"from": non_owner}
        )

def test_stakeToken(amount_staked):
    # arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Not in local environment")
    account = get_account()
    non_owner = get_account(index=1)
    token_farm, dapp_token = deploy_token_and_farm()
    # act
    dapp_token.approve(token_farm.address,amount_staked, {"from": account})
    token_farm.stakeToken(dapp_token.address, amount_staked, {"from": account})
    # assert
    assert(token_farm.stakingBalance(dapp_token.address, account.address) == amount_staked)
    assert token_farm.uniqueTokenStaked(account.address) == 1
    assert token_farm.stakers(0) == account.address
    return token_farm, dapp_token

def test_issueToken(amount_staked):
    # arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Not in local environment")
    account = get_account()
    token_farm, dapp_token = test_stakeToken(amount_staked)
    startingBalance = dapp_token.balanceOf(account.address)
    # act
    token_farm.issueToken({"from": account})
    # assert
    assert(
        dapp_token.balanceOf(account.address) == startingBalance + INITIAL_PRICE_FEED_VALUE
    )