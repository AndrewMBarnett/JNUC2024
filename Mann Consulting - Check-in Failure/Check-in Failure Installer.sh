#!/bin/zsh
###############################################################################
# Name:     Check-in Failure Installer
# Creator:  JMF Deploy
# Summary:  Installer for Mann's Check-in Failure Workflow
##
# Usage:    Run to install the workflow. If any of the objects exist already an error will be returned, delete any existing entries if you'd like to update them.
#
# Errors:   Any errors outputted will be from your Jamf server.
#
# Notice:   This script is part of JMF Deploy's Jamf Pro Workflows and has been distributed to the public as part of our JNUC 2024 presentation.
#           It is freely available for use by the community under the condition that it is provided “as is,” without any form of support, warranty, or guarantee of functionality, security, or fitness for any specific purpose.
#           JMF Deploy disclaims any and all liability for any damages, losses, or legal claims arising from the use, misuse, or inability to use this script. Users assume full responsibility for testing, deploying, and managing this script in their own environments.
###############################################################################

echo -n "Enter your Jamf Pro server URL (example https://company.jamfcloud.com): "
read jamfpro_url
echo -n "Enter your Jamf Pro admin account: "
read jamfpro_user

echo -n "Enter the password for the $jamfpro_user account: "
read -s jamfpro_password

echo "jamfpro url: $jamfpro_url"
echo "jamfpro user: $jamfpro_user"


    invalidateToken () {
	responseCode=$(/usr/bin/curl -w "%{http_code}" -H "Authorization: Bearer ${authorizationToken}" "${jamfpro_url}/api/v1/auth/invalidate-token" -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		access_token=""
		token_expiration_epoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
        authorizationTokenToken=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/invalidate-token" --silent --header "Authorization: Bearer ${authorizationToken}" -X POST)
        authorizationTokenToken=""
	fi
    }

function check_token() {

    apitokenCheck=$(/usr/bin/curl --write-out "%{http_code}" --silent --output /dev/null "${jamfpro_url}/api/v1/auth" --request GET --header "Authorization: Bearer ${authorizationToken}")
    echo "API Bearer Token Check: ${apitokenCheck}"
    case ${apitokenCheck} in
        200)
            echo "API Bearer Token is Valid"
            APIResult="Token Good"
            ;;
        401)
            echo "Authentication failed. Verify the credentials and URL being used for the request."
            APIResult="Failure"
            ;;
        403)
            echo "Invalid permissions. Verify the account being used has the proper permissions for the resource you are trying to access."
            APIResult="Failure"
            ;;
        404)
            echo "The resource you are trying to access could not be found. Check the URL and try again." 
            APIResult="Failure"
            ;;
        *)
            echo "Unknown error. Status code: ${apitokenCheck}"
            APIResult="Failure"
            ;;
    esac
}
jamfpro_url=${jamfpro_url%%/}
fulltoken=$(curl -s -X POST -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token")
authorizationToken=$(plutil -extract token raw - <<< "$fulltoken" )

check_token ${fulltoken}


baseDir=$(dirname $0)
echo "base directory: $baseDir"

echo "Uploading categories/JMF Deploy.xml"
curl -sS -H "Authorization: Bearer $authorizationToken" "$jamfpro_url/JSSResource/categories" -H "Content-Type: application/xml" -X "POST" --data-binary "@$baseDir/categories/JMF Deploy.xml"
sleep 20
echo ""

echo "Uploading computergroups/JMF Deploy - Check-in Failure = Fail.xml"
curl -sS -H "Authorization: Bearer $authorizationToken" "$jamfpro_url/JSSResource/computergroups" -H "Content-Type: application/xml" -X "POST" --data-binary "@$baseDir/computergroups/JMF Deploy - Check-in Failure = Fail.xml"
sleep 20
echo ""

echo "Uploading osxconfigurationprofiles/JMF Deploy - Check-in Failure Test.xml"
curl -sS -H "Authorization: Bearer $authorizationToken" "$jamfpro_url/JSSResource/osxconfigurationprofiles" -H "Content-Type: application/xml" -X "POST" --data-binary "@$baseDir/osxconfigurationprofiles/JMF Deploy - Check-in Failure Test.xml"
sleep 20
echo ""

echo "Uploading computergroups/JMF Deploy - Check-in Failure = Fix.xml"
curl -sS -H "Authorization: Bearer $authorizationToken" "$jamfpro_url/JSSResource/computergroups" -H "Content-Type: application/xml" -X "POST" --data-binary "@$baseDir/computergroups/JMF Deploy - Check-in Failure = Fix.xml"

invalidateToken