import pytest
from web3 import Web3
import web3

@pytest.fixture
def amount_staked():
    return Web3.toWei(1, "ether")