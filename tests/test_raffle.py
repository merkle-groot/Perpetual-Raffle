import time
import pytest
from random import randint
from brownie import VRFConsumer, RaffleNFT, Raffle, convert, network, reverts, rpc
from toolz.itertoolz import get
from scripts.helpful_scripts import (
    get_account,
    get_contract,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
)

noOfSlots = 1000
slotPrice = "0.001 ether"

@pytest.fixture(scope="module")
def test_contracts(get_keyhash, chainlink_fee):
    # Arrange
    account = get_account(0)
    print(account)
    nft = RaffleNFT.deploy(
        {"from": get_account()}
    )
    print(nft)

    raffle = Raffle.deploy(
        get_account(1),
        get_account(2),
        nft.address,
        slotPrice,
        get_keyhash,
        get_contract("vrf_coordinator").address,
        get_contract("link_token").address,
        chainlink_fee,
        noOfSlots,
        {"from": get_account()},
    )
    print(raffle.address)

    return nft, raffle

def test_nft_minting(test_contracts):
    nft, raffle = test_contracts
    currentPhase = raffle.currentPhase()
    assert currentPhase == -1

    isOwned = raffle.nftOwned()
    assert isOwned == False

    nft.sendToRaffle(
        raffle.address,
        1,
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        {"from": get_account()}
    )
    currentPhase = raffle.currentPhase()
    assert currentPhase == 0

    isOwned = raffle.nftOwned()
    assert isOwned == True

def test_purchase_slots(test_contracts):
    nft, raffle = test_contracts
    noOfSlotsRaffle = raffle.numSlotsAvailable()
    assert noOfSlots == noOfSlotsRaffle

    raffle.purchaseSlot(
        10, 0, {
            "from": get_account(3),
            "value": "0.01 ether"
        }
    )

    slotsFilled = raffle.numSlotsFilled()
    assert slotsFilled == 10

def test_purchase_slots_no_ether_passed(test_contracts):
    nft, raffle = test_contracts

    slotsFilledBefore = raffle.numSlotsFilled()

    with reverts():
        raffle.purchaseSlot(
            10, 0, {
                "from": get_account(3)
            }
        )

    slotsFilledAfter = raffle.numSlotsFilled()
    assert slotsFilledBefore == slotsFilledAfter


def test_purchase_slots_more_than_max_slots(test_contracts):
    nft, raffle = test_contracts

    slotsFilledBefore = raffle.numSlotsFilled()
    with reverts():
        raffle.purchaseSlot(
            1001, 0, {
                "from": get_account(3),
                "value": "1.001 ether"
            }
        )
    slotsFilledAfter = raffle.numSlotsFilled()
    assert slotsFilledBefore == slotsFilledAfter

def test_purchase_slots_for_testing_refunds(test_contracts):
    nft, raffle = test_contracts

    for i in range(4,10):
        slotsToPurchase = randint(1, 100)
        totalPrice = round(slotsToPurchase * float(slotPrice[:-6]), 19)
        
        raffle.purchaseSlot(
            slotsToPurchase, 0, {
                "from": get_account(i),
                "value": str(totalPrice) + " ether"
            }
        )

    slotsToPurchase3 = randint(1, 100)
    totalPrice3 = round(slotsToPurchase3 * float(slotPrice[:-6]), 19)
    raffle.purchaseSlot(
        slotsToPurchase3, 0, {
            "from": get_account(3),
            "value": str(totalPrice3) + " ether"
        }
    )

def test_refund_slots(test_contracts):
    nft, raffle = test_contracts

    noOfSlotsFilledBefore = raffle.numSlotsFilled()

    slotOwners = list(raffle.getSlotOwners())
    slotsToDelete = []

    for i in range(len(slotOwners)):
        if slotOwners[i] == get_account(3):
            slotsToDelete.append(i)
    
    print(len(slotsToDelete))

    accout3DetailsBefore = list(raffle.addressToSlotsOwner(get_account(3)))

    assert accout3DetailsBefore == [len(slotsToDelete), len(slotsToDelete), 1]

    print(slotsToDelete)

    # Call Refund Fn
    raffle.refundSlot(slotsToDelete, {"from": get_account(3)})

    accout3DetailsAfter = list(raffle.addressToSlotsOwner(get_account(3)))

    noOfSlotsFilledAfter= raffle.numSlotsFilled()

    # print("No of Slots", len(listOfSlots))
    # print("Before ", listOfInfoBefore[0])
    # print("Timestamp ", listOfSlots[1])
    # print("After ", listOfInfoAfter[0])
    # print("ToDelete ", len(slotsToDelete))

    assert accout3DetailsAfter == [0, 0, 1]
    assert noOfSlotsFilledBefore == noOfSlotsFilledAfter + len(slotsToDelete)



def test_enter_lock_period(test_contracts):
    nft, raffle = test_contracts

    raffle.enterLockPeriod()
    isPaused = raffle.paused()

    assert isPaused == True

def test_forward_time_by_7days():
    rpc.sleep(60*60*24*7)

def test_can_request_random_number(get_keyhash, chainlink_fee, test_contracts):
    nft, raffle = test_contracts

    get_contract("link_token").transfer(
        raffle.address, chainlink_fee * 3, {"from": get_account()}
    )
    
    requestId = raffle.exitLockPeriod()
    print(requestId.return_value)
    
    
    get_contract("vrf_coordinator").callBackWithRandomness(
        requestId.return_value, 777, raffle.address, {"from": get_account()}
    )

    assert raffle.randomResult() > 0
    print("Result:", raffle.randomResult())
    print("TOtal Slots:", raffle.numSlotsFilled())

    isPaused = raffle.paused()
    assert isPaused == False

def test_disburse_winner(test_contracts):
    nft, raffle = test_contracts

    result = raffle.disburseWinner()

    isSent = raffle.nftOwned()
    assert isSent == False
    
def test_new_round(test_contracts):
    nft, raffle = test_contracts
    currentPhase = raffle.currentPhase()
    assert currentPhase == -1

    isOwned = raffle.nftOwned()
    assert isOwned == False

    nft.sendToRaffle(
        raffle.address,
        2,
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        {"from": get_account()}
    )
    currentPhase = raffle.currentPhase()
    assert currentPhase == 0

    noOfRounds = raffle.noOfRounds()
    assert noOfRounds == 2

    isOwned = raffle.nftOwned()
    assert isOwned == True

def test_get_free_slots(test_contracts):
    nft, raffle = test_contracts

    account4DetailsBefore = raffle.addressToSlotsOwner(get_account(4))
    print(list(account4DetailsBefore))

    maxFreeSlots = int(account4DetailsBefore[1]/10) + 1
    print(maxFreeSlots)

    raffle.purchaseSlot(
        maxFreeSlots, 1, {
            "from": get_account(4),
        }
    )

    account4DetailsAfter = list(raffle.addressToSlotsOwner(get_account(4)))
    assert account4DetailsAfter == [account4DetailsBefore[0]+ maxFreeSlots, account4DetailsBefore[0], 2]

def test_free_slots_above_max(test_contracts):
    nft, raffle = test_contracts

    account5DetailsBefore = raffle.addressToSlotsOwner(get_account(5))
    print(list(account5DetailsBefore))

    maxFreeSlots = int(account5DetailsBefore[1]/10) + 2
    print(maxFreeSlots)

    with reverts():
        raffle.purchaseSlot(
            maxFreeSlots, 1, {
                "from": get_account(5),
            }
        )

    account5DetailsAfter = list(raffle.addressToSlotsOwner(get_account(5)))
    assert account5DetailsAfter == account5DetailsBefore

    






