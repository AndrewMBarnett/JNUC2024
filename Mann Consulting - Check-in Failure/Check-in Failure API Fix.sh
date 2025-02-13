#!/bin/zsh
###############################################################################
# Name:     Check-in Failure API Fix
# Creator:  Mann Consulting
# Summary:  Redeploys the Jamf Framework for eligible computers. Requires Mann's Jamf Check-in Failure workflow installed in the Jamf Server.
##
#
# Notice:   This script is part of Mann Consulting's Jamf Pro Workflows and has been distributed to the public as part of our JNUC 2024 presentation.
#           It is freely available for use by the community under the condition that it is provided “as is,” without any form of support, warranty, or guarantee of functionality, security, or fitness for any specific purpose.
#           Mann Consulting disclaims any and all liability for any damages, losses, or legal claims arising from the use, misuse, or inability to use this script. Users assume full responsibility for testing, deploying, and managing this script in their own environments.
###############################################################################

echo -n "Please enter your Jamf Pro server URL (i.e. https://company.jamfcloud.com/) : "
read jamfpro_url
echo -n "Please enter your Jamf Pro user account : "
read jamfpro_user
echo -n "Please enter the password for the $jamfpro_user account: "
read -s jamfpro_password
echo

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

jamfpro_url=${jamfpro_url%%/}
fulltoken=$(curl -s -X POST -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token")
authorizationToken=$(plutil -extract token raw - <<< "$fulltoken" )

binaryComputerGroup=$(curl -s -X GET "$jamfpro_url/JSSResource/computergroups/name/JMF%20Deploy%20-%20Check-in%20Failure%20%3D%20Fix" -H "accept: application/xml" -H "Authorization: Bearer $authorizationToken" | xmllint --format -| grep -m1 id | cut -d '>' -f2 | cut -d '<' -f1)
echo "Recalculating Group Memberships..."
curl -s -X POST "$jamfpro_url/api/v1/smart-computer-groups/${binaryComputerGroup}/recalculate" -H "accept: application/json" -H "Authorization: Bearer $authorizationToken"
echo
binaryComputers=($(curl -s -X GET "$jamfpro_url/JSSResource/computergroups/id/$binaryComputerGroup" -H "accept: application/xml" -H "Authorization: Bearer $authorizationToken" | xmllint --format - | grep id | cut -d '>' -f 2 | cut -d '<' -f 1 | tail -n +3 | tr '\n' ' '))


if [[ ${#binaryComputers[@]} -eq 0 ]]; then
  echo "No computers need a redeploy"
  exit
fi

echo "Flushing pending MDM commands for Binary Repair..."
curl -s -X DELETE "$jamfpro_url/JSSResource/commandflush/computergroups/id/$binaryComputerGroup/status/Pending+Failed" -H "accept: application/xml" -H "Authorization: Bearer $authorizationToken"
echo
for i in $binaryComputers; do
  echo "Reinstalling Framework for Computer ID $i"
  echo -n
  curl -X POST "$jamfpro_url/api/v1/jamf-management-framework/redeploy/$i" -H "accept: application/json" -H "Authorization: Bearer $authorizationToken"
  echo
  sleep 1
done

invalidateToken