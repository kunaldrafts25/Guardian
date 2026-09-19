import time
from unittest.mock import patch

from aws.cognito_triggers import (
    create_auth_challenge,
    define_auth_challenge,
    verify_auth_challenge,
)


def test_define_challenge_issues_tokens_only_after_success():
    initial = {"request": {"session": []}, "response": {}}
    assert define_auth_challenge(initial, None)["response"] == {
        "issueTokens": False,
        "failAuthentication": False,
        "challengeName": "CUSTOM_CHALLENGE",
    }
    success = {
        "request": {
            "session": [
                {"challengeName": "CUSTOM_CHALLENGE", "challengeResult": True}
            ]
        },
        "response": {},
    }
    result = define_auth_challenge(success, None)["response"]
    assert result["issueTokens"] is True
    assert result["failAuthentication"] is False


def test_define_challenge_stops_after_five_failures():
    event = {
        "request": {
            "session": [
                {"challengeName": "CUSTOM_CHALLENGE", "challengeResult": False}
                for _ in range(5)
            ]
        },
        "response": {},
    }
    result = define_auth_challenge(event, None)["response"]
    assert result["issueTokens"] is False
    assert result["failAuthentication"] is True


@patch("aws.cognito_triggers._sns_client")
def test_create_challenge_sends_transactional_sms(mock_client):
    event = {
        "request": {
            "challengeName": "CUSTOM_CHALLENGE",
            "userAttributes": {"phone_number": "+919876543210"},
        },
        "response": {},
    }
    result = create_auth_challenge(event, None)
    private = result["response"]["privateChallengeParameters"]
    assert len(private["answer"]) == 6
    assert private["answer"].isdigit()
    assert int(private["expiresAt"]) > int(time.time())
    mock_client.return_value.publish.assert_called_once()


def test_verify_challenge_rejects_expired_and_accepts_current_code():
    valid = {
        "request": {
            "privateChallengeParameters": {
                "answer": "123456",
                "expiresAt": str(int(time.time()) + 60),
            },
            "challengeAnswer": "123456",
        },
        "response": {},
    }
    assert verify_auth_challenge(valid, None)["response"]["answerCorrect"] is True
    expired = {
        "request": {
            "privateChallengeParameters": {
                "answer": "123456",
                "expiresAt": str(int(time.time()) - 1),
            },
            "challengeAnswer": "123456",
        },
        "response": {},
    }
    assert verify_auth_challenge(expired, None)["response"]["answerCorrect"] is False
