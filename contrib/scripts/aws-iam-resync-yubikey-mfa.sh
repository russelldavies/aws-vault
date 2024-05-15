#!/bin/sh
# Resync a Yubikey TOTP device to IAM user
# By default the device name is set to "YubiKey-<serial number>" but can be
# overridden with the $MFA_DEVICE_NAME environment variable.

set -eu

if [ -z "${MFA_DEVICE_NAME:-}" ]; then
  MFA_DEVICE_NAME="YubiKey-$(ykman list --serials | tr -d '\n')"
fi

ACCOUNT_ARN=$(aws sts get-caller-identity --query Arn --output text)

# Assume that the final portion of the ARN is the username
# Works for ARNs like `users/<user>` and `users/engineers/<user>`
USERNAME=$(echo "$ACCOUNT_ARN" | rev | cut -d/ -f1 | rev)

ACCOUNT_ID=$(echo "$ACCOUNT_ARN" | cut -d: -f5)
SERIAL_NUMBER="arn:aws:iam::${ACCOUNT_ID}:mfa/${MFA_DEVICE_NAME}"

CODE1=$(ykman oath accounts code -s "$SERIAL_NUMBER")

WAIT_TIME=$((30-$(date +%s)%30))
echo "Waiting $WAIT_TIME seconds before generating a second code" >&2
sleep $WAIT_TIME

CODE2=$(ykman oath accounts code -s "$SERIAL_NUMBER")

aws iam resync-mfa-device \
  --user-name "$USERNAME" \
  --serial-number "$SERIAL_NUMBER" \
  --authentication-code1 "$CODE1" \
  --authentication-code2 "$CODE2"
