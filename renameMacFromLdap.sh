#!/bin/bash

# Variables initialisation
version="renameMacFromOpenDirectory v1.6 - 2022, Yvan Godard [godardyvan@gmail.com]"
versionOSX=$(sw_vers -productVersion | awk -F '.' '{print $(NF-1)}')
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
help="no"
dnUserBranch="cn=users"
dnComputerBranch="cn=computers"
dnGroupsComputers="cn=computer_groups"
dnListsComputers="cn=computer_lists"
logActive=0
withLdapBind="no"
addCommentToLdap=0
computerNamePrefix=""
detailModeleRetina=0
detailModeleTouchBar=0
detailModeleEcran=0
detailModeleTailleEcran=""
computerCn=""
mode=""
attributOwnedComputer=""
attributComputerOwner=""
attributComment="description"
computerOwner=""
ligneDebut=0
ligneFin=0
verbosity=0
syncAttributes=0
githubRemoteScript="https://raw.githubusercontent.com/yvangodard/renameMacFromOpenDirectory/master/renameMacFromLdap.sh"
log="/var/log/renameMacFromOpenDirectory.log"
logTemp=$(mktemp /tmp/renameMacFromOpenDirectory_LogTemp.XXXXX)
computerLdapEntryTemp=$(mktemp /tmp/renameMacFromOpenDirectory_computerLdapEntryTemp.XXXXX)
computerLdapEntryContent=$(mktemp /tmp/renameMacFromOpenDirectory_computerLdapEntryContent.XXXXX)
computerNameTemp=$(mktemp /tmp/renameMacFromOpenDirectory_computerNameTemp.XXXXX)
userLdapList=$(mktemp /tmp/renameMacFromOpenDirectory_userLdapList.XXXXX)
userLdapListDecoded=$(mktemp /tmp/renameMacFromOpenDirectory_userLdapListDecoded.XXXXX)
groupsOfComputerTemp=$(mktemp /tmp/renameMacFromOpenDirectory_groupsOfComputerTemp.XXXXX)
groupsOfComputerClean=$(mktemp /tmp/renameMacFromOpenDirectory_groupsOfComputerClean.XXXXX)
listsOfComputerTemp=$(mktemp /tmp/renameMacFromOpenDirectory_listsOfComputerTemp.XXXXX)
listsOfComputerClean=$(mktemp /tmp/renameMacFromOpenDirectory_listsOfComputerClean.XXXXX)
scriptsDirCompatibilityCheck="/usr/local/scriptsDirCompatibilityCheck"
# Sous-script
scriptCheckMacOS10_8CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.8-mountainlion-compatibility.py"
scriptCheckMacOS10_8Compatibility="check-10.8-mountainlion-compatibility.py"
scriptCheckMacOS10_9CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.9-mavericks-compatibility.py"
scriptCheckMacOS10_9Compatibility="check-10.9-mavericks-compatibility.py"
scriptCheckMacOS10_10CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.10-yosemite-compatibility.py"
scriptCheckMacOS10_10Compatibility="check-10.10-yosemite-compatibility.py"
scriptCheckMacOS10_11CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.11-elcapitan-compatibility.py"
scriptCheckMacOS10_11Compatibility="check-10.11-elcapitan-compatibility.py"
scriptCheckMacOS10_12CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.12-sierra-compatibility.py"
scriptCheckMacOS10_12Compatibility="check-10.12-sierra-compatibility.py"
scriptCheckMacOS10_13CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.13-highsierra-compatibility.py"
scriptCheckMacOS10_13Compatibility="check-10.13-highsierra-compatibility.py"
scriptCheckMacOS10_14ompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.14-mojave-compatibility.py"
scriptCheckMacOS10_14Compatibility="check-10.14-mojave-compatibility.py"
scriptCheckMacOS10_15CompatibilityGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-10.15-catalina-compatibility.py"
scriptCheckMacOS10_15Compatibility="check-10.15-catalina-compatibility.py"
scriptCheckForMalwareGit="https://raw.githubusercontent.com/yvangodard/adminscripts/master/check-for-osx-malware.sh"
scriptCheckForMalware="check-for-osx-malware.sh"
scriptCheckSsdGit="https://raw.githubusercontent.com/yvangodard/testSSD/master/testSSD.sh"
scriptCheckSsd="testSSD.sh"

help () {
	echo -e "\n$version\n"
	echo -e "Cet outil est destiné à renommer un Mac (ComputerName,LocalHostName,HostName) en utilisant les données contenues dans l'OpenDirectory."
	echo -e "\nAvertissement :"
	echo -e "Cet outil est mis à disposition sans aucune garantie ni support."
	echo -e "\nUtilisation :"
	echo -e "./$scriptName [-h] | -s <URL LDAP> -b <LDAP DN Base> -m <mode>" 
	echo -e "                       [-a <admin LDAP UID>] [-p <admin LDAP password>]"
	echo -e "                       [-u <DN relatif branche users>] [-c <DN relatif branche computers>]"
	echo -e "                       [-d <préfixe machines>] [-w <ajouter commentaire LDAP>]"
	echo -e "                       [-o <attribut propriétaire>] [-O <attribut propriété>] [-W <attribut commentaire>]"
	echo -e "                       [-j <fichier log>]"
	echo -e "                       [-v <niveau de verbosité>]"
	echo -e "\nPour afficher l'aide :"
	echo -e "\t-h :                                affiche cette aide et quitte"
	echo -e "\nParamètres obligatoires :"
	echo -e "\t-s <URL LDAP> :                     adresse du serveur OpenDirectory, au format 'ldap://'"
	echo -e "\t-b <base namespace> :               DN de base pour chaque entrée du LDAP (ex. : 'dc=server,dc=office,dc=com')"
	echo -e "\t-m <mode> :                         mode utilisé pour changer le nom :"
	echo -e "\t                                    - 'fromldap' récupèrera le nom de la machine dans l'OpenDirectory et l'appliquera localement"
	echo -e "\t                                    - 'fromspecs' génèrera un nom de manchine contenant le type de machine"
	echo -e "\t                                    - 'fromspecswithldapupdate' génèrera un nom de manchine contenant le type de machine"
	echo -e "\t                                      et répercutera cette modification sur l'entrée LDAP de l'ordinateur"
	echo -e "\nParamètres optionnels :"
	echo -e "\t-a <admin LDAP UID> :               UID d'un administrateur OpenDirectory, si le bind est nécessaire pour"
	echo -e "\t                                    accéder au serveur LDAP. (ex. : 'diradmin')"
	echo -e "\t-p <admin LDAP password> :          mot de passe de l'administrateur OpenDirectory (sera demandé si manquant)"
	echo -e "\t-u <DN relatif branche users> :     DN relatif de la branche LDAP contenant les utilisateurs (ex. : 'cn=allusers', par défaut : '${dnUserBranch}')"
	echo -e "\t-c <DN relatif branche computers> : DN relatif de la branche LDAP contenant les computers (ex. : 'cn=machines', par défaut : '${dnComputerBranch}')"
	echo -e "\t-d <préfixe machines> :             préfixe qui sera ajouté au nom de la machine (uniquement si '-m fromspecs' est utilisé)"
	echo -e "\t-w <ajouter commentaire LDAP> :     en utilisant '-w addcomment', les principales spécifications de la machine seront ajoutées en commentaire"
	echo -e "\t                                    sur l'entrée LDAP correspondante."
	echo -e "\t-o <attribut propriétaire> :        entrez avec ce paramètre l'attribut LDAP qui contient le DN complet du propriétaire de la machine,"
	echo -e "\t                                    si ce paramètre est utilisé, le nom du propriétaire sera intégré dans le nom de la machine généré"
	echo -e "\t-O <attribut propriété> :           entrez avec ce paramètre l'attribut LDAP qui permet d'identifier dans une entrée 'user' du LDAP"
	echo -e "\t                                    les DN complets de toutes les machines appartenant à cet utilisateur"
	echo -e "\t-W <attribut commentaire> :         entrez avec ce paramètre l'attribut LDAP qui contient le champ commentaire pour une entrée"
	echo -e "\t                                    'ordinateur' du LDAP (cette option ne peut être utilisée que si '-w addcomment' est utilisé)"
	echo -e "\t-j <fichier log> :                  active la journalisation à la place de la sortie standard. Mettre en argument le chemin complet"
	echo -e "\t                                    du fichier de log à utiliser (ex. : '/var/log/LDAP-rename.log') "
	echo -e "\t                                    du fichier de log pour le chemin par défaut (${log})"
	echo -e "\t-v <niveau de verbosité> :          niveau de verbosité du script (0 ou 1), par défaut '-v ${verbosity}'"
	exit 0
}

function error () {
	echo -e "\n*** Erreur ${1} ***"
	echo -e ${2}
	alldone ${1}
}

function alldone () {
	# Journalisation si nécessaire et redirection de la sortie standard
	[ ${1} -eq 0 ] && echo "" && echo "[${scriptName}] Processus terminé OK !"
	if [ ${logActive} -eq 1 ]; then
		exec 1>&6 6>&-
		[[ ! -f ${log} ]] && touch ${log}
		cat ${logTemp} >> ${log}
		cat ${logTemp}
	fi
	# Suppression des fichiers et répertoires temporaires
	[[ -f ${logTemp} ]] && rm -r ${logTemp}
	[[ -f ${computerLdapEntryTemp} ]] && rm -r ${computerLdapEntryTemp}
	[[ -f ${computerLdapEntryContent} ]] && rm -r ${computerLdapEntryContent}
	[[ -f ${computerNameTemp} ]] && rm -r ${computerNameTemp}
	exit ${1}
}

# Fonction utilisée plus tard pour les résultats de requêtes LDAP encodées en base64
function base64decode () {
	echo ${1} | grep :: > /dev/null 2>&1
	if [ $? -eq 0 ] 
		then
		value=$(echo ${1} | grep :: | awk '{print $2}' | perl -MMIME::Base64 -ne 'printf "%s\n",decode_base64($_)' )
		attribute=$(echo ${1} | grep :: | awk '{print $1}' | awk 'sub( ".$", "" )' )
		echo "${attribute} ${value}"
	else
		echo ${1}
	fi
}

# Fonction utilisée pour supprimer les sauts de ligne dans retours de commandes ldapsearch
function ldapUnSplitLines () {
	perl -n -e 'chomp ; print "\n" unless (substr($_,0,1) eq " " || !defined($lines)); $_ =~ s/^\s+// ; print $_ ; $lines++;' -i "${1}"
}

# Fonction un peu solide utilisée pour supprimer les caratères accentués
function sanizette () {
	echo "${1}" | perl -CS -pe 's/\N{U+00E0}/a/g' \
	| perl -CS -pe 's/\N{U+00E1}/a/g' \
	| perl -CS -pe 's/\N{U+00E2}/a/g' \
	| perl -CS -pe 's/\N{U+00E3}/a/g' \
	| perl -CS -pe 's/\N{U+00E4}/a/g' \
	| perl -CS -pe 's/\N{U+00E5}/a/g' \
	| perl -CS -pe 's/\N{U+00E6}/ae/g' \
	| perl -CS -pe 's/\N{U+00E7}/c/g' \
	| perl -CS -pe 's/\N{U+00E8}/e/g' \
	| perl -CS -pe 's/\N{U+00E9}/e/g' \
	| perl -CS -pe 's/\N{U+00EA}/e/g' \
	| perl -CS -pe 's/\N{U+00EB}/e/g' \
	| perl -CS -pe 's/\N{U+00EC}/i/g' \
	| perl -CS -pe 's/\N{U+00ED}/i/g' \
	| perl -CS -pe 's/\N{U+00EE}/i/g' \
	| perl -CS -pe 's/\N{U+00EF}/i/g' \
	| perl -CS -pe 's/\N{U+00F1}/n/g' \
	| perl -CS -pe 's/\N{U+00F2}/o/g' \
	| perl -CS -pe 's/\N{U+00F3}/o/g' \
	| perl -CS -pe 's/\N{U+00F4}/o/g' \
	| perl -CS -pe 's/\N{U+00F5}/o/g' \
	| perl -CS -pe 's/\N{U+00F6}/o/g' \
	| perl -CS -pe 's/\N{U+00F8}/o/g' \
	| perl -CS -pe 's/\N{U+00F9}/u/g' \
	| perl -CS -pe 's/\N{U+00FA}/u/g' \
	| perl -CS -pe 's/\N{U+00FB}/u/g' \
	| perl -CS -pe 's/\N{U+00FC}/u/g' \
	| perl -CS -pe 's/\N{U+0169}/u/g' \
	| perl -CS -pe 's/\N{U+00C0}/A/g' \
	| perl -CS -pe 's/\N{U+00C1}/A/g' \
	| perl -CS -pe 's/\N{U+00C2}/A/g' \
	| perl -CS -pe 's/\N{U+00C3}/A/g' \
	| perl -CS -pe 's/\N{U+00C4}/A/g' \
	| perl -CS -pe 's/\N{U+00C5}/A/g' \
	| perl -CS -pe 's/\N{U+00C6}/AE/g' \
	| perl -CS -pe 's/\N{U+00C7}/C/g' \
	| perl -CS -pe 's/\N{U+00C8}/E/g' \
	| perl -CS -pe 's/\N{U+00C9}/E/g' \
	| perl -CS -pe 's/\N{U+00CA}/E/g' \
	| perl -CS -pe 's/\N{U+00CB}/E/g' \
	| perl -CS -pe 's/\N{U+00CC}/I/g' \
	| perl -CS -pe 's/\N{U+00CD}/I/g' \
	| perl -CS -pe 's/\N{U+00CE}/I/g' \
	| perl -CS -pe 's/\N{U+00CF}/I/g' \
	| perl -CS -pe 's/\N{U+00D1}/N/g' \
	| perl -CS -pe 's/\N{U+00D2}/O/g' \
	| perl -CS -pe 's/\N{U+00D3}/O/g' \
	| perl -CS -pe 's/\N{U+00D4}/O/g' \
	| perl -CS -pe 's/\N{U+00D5}/O/g' \
	| perl -CS -pe 's/\N{U+00D6}/O/g' \
	| perl -CS -pe 's/\N{U+00D8}/O/g' \
	| perl -CS -pe 's/\N{U+00D9}/U/g' \
	| perl -CS -pe 's/\N{U+00DA}/U/g' \
	| perl -CS -pe 's/\N{U+00DB}/U/g' \
	| perl -CS -pe 's/\N{U+00DC}/U/g' \
	| perl -CS -pe 's/\N{U+0168}/U/g'
}

# Vérification des options/paramètres du script 
optsCount=0
while getopts "hs:b:m:a:p:u:d:j:o:O:w:W:v:" option
do
	case "$option" in
		h)	help="yes"
						;;
	    s) 	ldapUrl=${OPTARG}
			let optsCount=$optsCount+1
						;;
		b)	ldapDnBase=${OPTARG}
			let optsCount=$optsCount+1
						;;
	    m) 	mode=${OPTARG}
			[[ ${mode} != "fromldap" ]] && [[ ${mode} != "fromspecs" ]] && [[ ${mode} != "fromspecswithldapupdate" ]] && error 6 "Le mode n'a pas été renseigné correctement : utiliser '-m fromldap' ou '-m fromspecs' ou '-m fromspecswithldapupdate'."
			let optsCount=$optsCount+1
						;;
		a)	ldapAdminUid=${OPTARG}
			[[ ${ldapAdminUid} != "" ]] && withLdapBind="yes"
						;;
		p)	ldapAdminPass=${OPTARG}
                        ;;
		u) 	dnUserBranch=${OPTARG}
						;;
		c) 	dnComputerBranch=${OPTARG}
						;;
		d) 	computerNamePrefix=${OPTARG}
						;;
		o) 	attributComputerOwner=${OPTARG}
						;;
		O) 	attributOwnedComputer=${OPTARG}
						;;
		w) 	[[ ${OPTARG} = "addcomment" ]] && addCommentToLdap=1
			[[ ${OPTARG} != "addcomment" ]] && error 8 "L'option '-w' a été utilisée de manière incorrecte. Utilisez '-w addcomment' !"
						;;
		W)  attributComment=${OPTARG}
						;;
        j)	[[ ${OPTARG} != "default" ]] && log=${OPTARG}
			logActive=1
                        ;;
        v)	verbosity=${OPTARG}
			[[ ${verbosity} != "0" ]] && [[ ${verbosity} != "1" ]] && error 10 "Le niveau de verbosité n'est pas correct, utilisez '-v 0' ou '-v 1'."
			            ;;
		esac
done

if [[ ${optsCount} != "3" ]]; then
	help
	error 7 "Les paramètres obligatoires n'ont pas été renseignés."
fi

[[ ${help} = "yes" ]] && help

if [[ ${withLdapBind} = "yes" ]] && [[ ${ldapAdminPass} = "" ]]; then
	echo "Entrez le mot de passe LDAP pour uid=$ldapAdminUid,$dnUserBranch,$ldapDnBase :" 
	read -s ldapAdminPass
fi

# Redirection de la sortie strandard vers le fichier de log
if [ $logActive -eq 1 ]; then
	echo -e "\nMerci de patienter ..."
	exec 6>&1
	exec >> ${logTemp}
fi

echo ""
echo "****************************** `date` ******************************"
echo "${scriptName} démarré..."
echo "sur Mac OSX version $(sw_vers -productVersion)"
echo ""

# Check URL
function checkUrl() {
  command -p curl -Lsf "$1" >/dev/null
  echo "$?"
}

# Changement du séparateur par défaut et mise à jour auto
OLDIFS=$IFS
IFS=$'\n'
# Auto-update script
if [[ $(checkUrl ${githubRemoteScript}) -eq 0 ]] && [[ $(md5 -q "$0") != $(curl -Lsf ${githubRemoteScript} | md5 -q) ]]; then
	[[ -e "$0".old ]] && rm "$0".old
	mv "$0" "$0".old
	curl -Lsf ${githubRemoteScript} >> "$0"
	echo "Une mise à jour de ${0} est disponible."
	echo "Nous la téléchargeons depuis GitHub."
	if [ $? -eq 0 ]; then
		echo "Mise à jour réussie, nous relançons le script."
		chmod +x "$0"
		exec ${0} "$@"
		exit $0
	else
		echo "Un problème a été rencontré pour mettre à jour ${0}."
		echo "Nous poursuivons avec l'ancienne version du script."
	fi
	echo ""
fi
IFS=$OLDIFS


if [[ ${withLdapBind} = "no" ]] && [[ ${addCommentToLdap} = "1" ]]; then
	echo -e "Attention : vous avez utilisé l'option '-w addcomment' sans entrer les paramètres d'accès en écriture au LDAP"
	echo -e "('-a <admin LDAP UID>' et '-p <admin LDAP password>'). Nous poursuivons sans l'option '-w addcomment'.\n"
	addCommentToLdap=0
fi

# Vérification attribut commentaire
[[ ${attributComment} != "description" ]] && [[ ${addCommentToLdap} -ne 1 ]] && echo -e "Attention : vous avez utilisé l'option '-W ${attributComment}' mais sans utiliser '-w addcomment',\nl'option '-W ${attributComment}' sera ignorée.\n"

# Renseignons l'attribut user contenant les DN des machines dont il est propriétaire
[[ ! -z ${attributComputerOwner} ]] && [[ ! -z ${attributOwnedComputer} ]] && syncAttributes=1
[[ ${syncAttributes} = "1" ]] && [[ -z ${ldapAdminPass} ]] && echo -e "\nLe mot de passe de l'administrateur LDAP est vide. Nous ne pouvons pas écrire les attributs '-o ${attributComputerOwner}' et/ou '-O {attributOwnedComputer}." && syncAttributes=0
[[ ${syncAttributes} = "1" ]] && [[ -z ${ldapAdminUid} ]] && echo -e "\nL'UID de l'administrateur LDAP est vide. Nous ne pouvons pas écrire les attributs '-o ${attributComputerOwner}' et/ou '-O {attributOwnedComputer}." && syncAttributes=0

# Test connecté à internet
dig +short myip.opendns.com @resolver1.opendns.com > /dev/null 2>&1
[[ $? -ne 0 ]] && error 1 "Non connecté à internet. Cet outil nécessite une connection pour fonctionner !"

# Test LDAP joignable
echo "Connection au LDAP ${ldapUrl}..."
[[ ${withLdapBind} = "no" ]] && ldapCommandBegin="ldapsearch -LLL -H ${ldapUrl} -x"
[[ ${withLdapBind} = "yes" ]] && ldapCommandBegin="ldapsearch -LLL -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x"

${ldapCommandBegin} -b ${dnComputerBranch},${ldapDnBase} > /dev/null 2>&1
[[ $? -ne 0 ]] && error 3 "Problème de connexion au serveur LDAP ${ldapUrl}.\nVérifiez vos paramètres de connexion."

# Si LDAP joignable
# On récupère l'UUID Hardware du Mac (pour vérifier ensuite une concordance dans l'OpenDirectory)
hwuuid=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep Hardware\ UUID: | awk -F "Hardware UUID: " '{print $2}')
echo "${hwuuid}" | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]' > /dev/null 2>&1
[[ $? -ne 0 ]] && error 2 "L'UUID Hardware semble inccorect. Nous quittons."
[[ ! -z ${hwuuid} ]] && echo "- hwuuid : ${hwuuid}"

# On teste si l'UUID Matériel existe dans l'OpenDirectory
dnComputerToDecode=$(${ldapCommandBegin} -b ${dnComputerBranch},${ldapDnBase} apple-hwuuid | perl -n -e 'chomp ; print "\n" unless (substr($_,0,1) eq " " || !defined($lines)); $_ =~ s/^\s+// ; print $_ ; $lines++;' | grep -B1 ${hwuuid} | grep ^dn: | perl -p -e 's/dn: //g')
[[ -z ${dnComputerToDecode} ]] && error 4 "Problème pour retrouver la concordance de l'UUID Matériel dans l'OpenDirectory. Nous quittons."
# Décodage des informations
dnComputer=$(base64decode ${dnComputerToDecode})
echo "- dnComputer : ${dnComputer}"
echo "${dnComputer}" | awk -F ",${dnComputerBranch},${ldapDnBase}" '{print $1}' | grep "^cn=[a-zA-Z0-9=-_.]" > /dev/null 2>&1
[[ $? -ne 0 ]] && error 4 "Le DN de la machine semble incohérent ou n'est pas renseigné dans l'OpenDirectory. Nous quittons."
cnComputer=$(echo "${dnComputer}" | awk -F ",${dnComputerBranch},${ldapDnBase}" '{print $1}')

# On stocke le contenu de l'entrée LDIF dans un fichier temporaire
${ldapCommandBegin} -b ${dnComputerBranch},${ldapDnBase} ${cnComputer} apple-generateduid apple-hwuuid apple-realname cn ${attributComputerOwner} > ${computerLdapEntryTemp}
ldapUnSplitLines "${computerLdapEntryTemp}"
oldIfs=$IFS ; IFS=$'\n'
for line in $(cat ${computerLdapEntryTemp})
do
	base64decode ${line} >> ${computerLdapEntryContent}
done
IFS=$oldIfs

# Récupération des données (pour partie depuis les specs de la machine, pour partie depuis le LDAP)
nomModele=$(ioreg -l | grep "product-name" | cut -d ""="" -f 2 | sed -e s/[^[:alnum:]]//g | sed s/[0-9]//g)
#modelMac=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | perl -MLWP::Simple -MXML::Simple -lane '$c=substr($F[3],8)if/Serial/}{print XMLin(get(q{https://support-sp.apple.com/sp/product?cc=}.$c))->{configCode}')
modelMac=$(curl -s https://support-sp.apple.com/sp/product?cc=`/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | awk '/Serial/ {print $4}' | cut -c 9-` | sed 's|.*<configCode>\(.*\)</configCode>.*|\1|')
[[ ! -z ${modelMac} ]] && echo "- model : ${modelMac}"

# Récupération des données (pour partie depuis le LDAP)
ldapAppleRealName=$(cat ${computerLdapEntryContent} | grep ^apple-realname: | perl -p -e 's/apple-realname: //g')
ldapAppleCn=$(cat ${computerLdapEntryContent} | grep ^cn: | perl -p -e 's/cn: //g')
computerOwner=$(cat ${computerLdapEntryContent} | grep ^${attributComputerOwner}: | sed 's/'"${attributComputerOwner}: "'//g')
[[ ${mode} = "fromldap" ]] && [[ ! -z ${ldapAppleRealName} ]] && echo "- ldapAppleRealName : ${ldapAppleRealName}"
[[ ${mode} = "fromldap" ]] && [[ ! -z ${ldapAppleCn} ]] && echo "- ldapAppleCn : ${ldapAppleCn}"
[[ ! -z ${computerOwner} ]] && echo "- computerOwner : ${computerOwner}"

# Recherche de spécifications détaillées pour créer le nom de la machine
curl -s https://support-sp.apple.com/sp/product?cc=`ioreg -l | grep "IOPlatformSerialNumber" | cut -d ""="" -f 2 | sed -e s/[^[:alnum:]]//g | cut -c 9-` > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	detailModele=$(curl -s https://support-sp.apple.com/sp/product?cc=`ioreg -l | grep "IOPlatformSerialNumber" | cut -d ""="" -f 2 | sed -e s/[^[:alnum:]]//g | cut -c 9-` | sed 's|.*<configCode>\(.*\)</configCode>.*|\1|' | sed 's|.*(\(.*\)).*|\1|')
	echo $detailModele | grep Retina > /dev/null 2>&1
	[[ $? -eq 0 ]] && detailModeleRetina=1
	echo $detailModele | grep "\-inch" > /dev/null 2>&1
	[[ $? -eq 0 ]] && detailModeleEcran=1 && detailModeleTailleEcran=$(for line in $(echo $detailModele) ; do echo ${line} | grep "\-inch" | awk '{print($1)}' | cut -b-2 ; done)
else
	error 9 "Problème de connexion internet lors de la connexion à la base de données Apple.\nMerci de vérifier votre connectivité internet avant de relancer !"
fi
# Test touch bar
ioreg | grep "AppleEmbeddedOSSupportHost" > /dev/null 2>&1
[[ $? -eq 0 ]] && detailModeleTouchBar=1

if [[ ${mode} = "fromspecs" ]] || [[ ${mode} = "fromspecswithldapupdate" ]] ; then
	case "$nomModele" in
					"MacBookPro" )
					;;
					"MacBookAir" )
					;;
					"MacBook" )
					;;
					"MacPro" )
					;;
					"iMac" )
					;;
					"Macmini" )
					;;
					"Xserve" )
					;;
					* )
					error 5 "Modèle de Mac inconnu ou non reconnu."
					;;
	esac

	# Test si l'ordinateur a un propriétaire et traitement de l'attribut contenant le DN du propriétaire
	if [[ -z ${attributComputerOwner} ]] || [[ -z ${computerOwner} ]]; then
		[[ ${verbosity} -eq 1 ]] && echo -e "\nL'ordinateur n'a pas d'attribut renseigné permettant d'identifier son propriétaire ou vous n'avez pas utilisé l'option '-o'.\nNous allons générer un nom avec le numéro de série pour identifier la machine.\n"
		serialNumber=$(ioreg -c "IOPlatformExpertDevice" | awk -F '"' '/IOPlatformSerialNumber/ {print $4}')
	elif [[ ! -z ${attributComputerOwner} ]]; then
		${ldapCommandBegin} -b ${computerOwner} > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			[[ ${verbosity} -eq 1 ]] && echo "Problème rencontré pour trouver le propriétaire de la machine. ${computerOwner} semble incorrect."
		else
			computerOwnerUID=$(echo ${computerOwner} | cut -d "","" -f 1)
			# On stocke le contenu de l'entrée LDIF dans un fichier temporaire
			ownerLdapEntryTemp=$(mktemp /tmp/renameMacFromOpenDirectory_ownerLdapEntryTemp.XXXXX)
			ownerLdapEntryContent=$(mktemp /tmp/renameMacFromOpenDirectory_ownerLdapEntryContent.XXXXX)
			${ldapCommandBegin} -b ${dnUserBranch},${ldapDnBase} ${computerOwnerUID} apple-realname cn > ${ownerLdapEntryTemp}
			ldapUnSplitLines "${ownerLdapEntryTemp}"
			oldIfs=$IFS ; IFS=$'\n'
			for line in $(cat ${ownerLdapEntryTemp})
			do
				base64decode ${line} >> ${ownerLdapEntryContent}
			done
			IFS=$oldIfs
			# Extraction du nom
			computerOwnerCN=$(cat ${ownerLdapEntryContent} | grep ^cn: | perl -p -e 's/cn: //g')
			[[ ! -z ${computerOwnerCN} ]] && echo -e "- computerOwnerCN : ${computerOwnerCN}\n"
		fi
	fi

	# Générons le nouveau nom
	[[ ! -z ${computerNamePrefix} ]] && echo "${computerNamePrefix}-" >> ${computerNameTemp}
	echo "${nomModele}" >> ${computerNameTemp} 
	[[ ${detailModeleEcran} -eq 1 ]] && echo "${detailModeleTailleEcran}" >> ${computerNameTemp}
	[[ ${detailModeleRetina} -eq 1 ]] && echo "-Retina" >> ${computerNameTemp}
	[[ ${detailModeleTouchBar} -eq 1 ]] && echo "-TouchBar" >> ${computerNameTemp}
	[[ ! -z ${computerOwnerCN} ]] && echo "--${computerOwnerCN}" >> ${computerNameTemp}
	[[ -z ${attributComputerOwner} ]] || [[ -z ${computerOwner} ]] && echo "-${serialNumber}" >> ${computerNameTemp}
	computerNewRealName=$(cat ${computerNameTemp} | perl -p -e 's/\n//g')
	computerNewCn=$(sanizette $(echo ${computerNewRealName} | perl -p -e 's/ /-/g'))

elif [[ ${mode} = "fromldap" ]]; then
	computerNewRealName=${ldapAppleRealName}
	computerNewCn=$(sanizette ${ldapAppleCn})
fi

# On applique le nouveau nom à la machine
echo ""
oldComputerName=$(/usr/sbin/scutil --get ComputerName)
if [[ "${oldComputerName}" != "${computerNewRealName}" ]] ; then
	echo "" && echo "On change le ComputerName de ${oldComputerName} par ${computerNewRealName}"
	/usr/sbin/scutil --set ComputerName "${computerNewRealName}"
	[[ $? -ne 0 ]] && error 11 "Problème lors de l'application de 'ComputerName ${computerNewRealName}'"
else
	echo "" && echo "Pas de nécessité de changer le ComputerName, déjà correct : ${computerNewRealName}"
fi
oldComputerLocalHostName=$(/usr/sbin/scutil --get LocalHostName)
if [[ "${oldComputerLocalHostName}" != "${computerNewCn}" ]] ; then
	echo "On change le LocalHostName de ${oldComputerLocalHostName} par ${computerNewCn}"
	/usr/sbin/scutil --set LocalHostName "${computerNewCn}"
	[[ $? -ne 0 ]] && error 11 "Problème lors de l'application de 'LocalHostName ${computerNewCn}'"
else
	echo "" && echo "Pas de nécessité de changer le LocalHostName, déjà correct : ${computerNewCn}"
fi

# Actualisation les entrées dans le LDAP si besoin
if [[ ${mode} = "fromspecswithldapupdate" ]]; then
	echo ""
	computerModifyLdapEntry=/tmp/renameMacFromOpenDirectory_computerModifyLdapEntry.ldif
	if [[ $(echo ${dnComputer} | cut -d "","" -f 1) != "cn=${computerNewCn}" ]]; then
		[[ -e ${computerModifyLdapEntry} ]] && rm -R ${computerModifyLdapEntry}
		echo "dn: ${dnComputer}" > ${computerModifyLdapEntry}
		echo "changetype: moddn" >> ${computerModifyLdapEntry}
		echo "newrdn: cn=${computerNewCn}" >> ${computerModifyLdapEntry}
		echo "deleteoldrdn: 1"  >> ${computerModifyLdapEntry}
		echo "newsuperior: ${dnComputerBranch},${ldapDnBase}" >> ${computerModifyLdapEntry}
		ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${computerModifyLdapEntry}
		[[ $? -ne 0 ]] && error 10 "Problème lors de la modification de l'attribut 'cn: ${computerNewCn}' de l'entrée '${dnComputer}' !"
		rm -R ${computerModifyLdapEntry}
		cnComputer="cn=${computerNewCn}"
		dnComputer="cn=${computerNewCn},${dnComputerBranch},${ldapDnBase}"
	fi
	if [[ "${ldapAppleRealName}" != "${computerNewRealName}" ]]; then
		[[ -e ${computerModifyLdapEntry} ]] && rm -R ${computerModifyLdapEntry}
		echo "dn: cn=${computerNewCn},${dnComputerBranch},${ldapDnBase}" > ${computerModifyLdapEntry}
		echo "changetype: modify" >> ${computerModifyLdapEntry}
		echo "replace: apple-realname" >> ${computerModifyLdapEntry}
		echo "apple-realname: ${computerNewRealName}" >> ${computerModifyLdapEntry}
		ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${computerModifyLdapEntry}
		[[ $? -ne 0 ]] && error 10 "Problème lors de la modification de l'attribut 'apple-realname: ${computerNewRealName}' de l'entrée '${dnComputer}' !"
		rm -R ${computerModifyLdapEntry}
	fi

	# Ménage pour renommer dans le LDAP les entrées ordinateurs qui ont changé de nom à l'intérieur de groupe(s) 
	# Liste des groupe dont l'ordinateur est membre
	${ldapCommandBegin} -b ${dnGroupsComputers},${ldapDnBase} dn >> ${groupsOfComputerTemp}
	ldapUnSplitLines "${groupsOfComputerTemp}"
	oldIfs=$IFS ; IFS=$'\n'
	for groupDn in $(cat ${groupsOfComputerTemp})
	do
		base64decode ${groupDn} | grep ^dn: | perl -p -e 's/dn: //g' | grep -v ^${dnGroupsComputers},${ldapDnBase} >> ${groupsOfComputerClean}
	done
	IFS=$oldIfs
	# Pour chaque groupe
	if [[ ! -z $(cat ${groupsOfComputerClean}) ]]; then
		for computerGroup in $(cat ${groupsOfComputerClean})
		do
			${ldapCommandBegin} -b ${computerGroup} memberUid | grep ${oldComputerLocalHostName} > /dev/null 2>&1
			# Si le nom ancien existe et qu'il y a un nouveau nom > changement dans le Ldap
			if [[ $? -eq 0 ]] && [[ "${oldComputerLocalHostName}" != "${computerNewCn}" ]]; then
				groupModifyLdapEntry=/tmp/renameMacFromOpenDirectory_groupModifyLdapEntry.ldif
				[[ -e ${groupModifyLdapEntry} ]] && rm -R ${groupModifyLdapEntry}
				echo "dn: ${computerGroup}" > ${groupModifyLdapEntry}
				echo "changetype: modify" >> ${groupModifyLdapEntry}
				echo "delete: memberUid" >> ${groupModifyLdapEntry}
				echo "memberUid: ${oldComputerLocalHostName}" >> ${groupModifyLdapEntry}
				echo "-" >> ${groupModifyLdapEntry}
				echo "add: memberUid" >> ${groupModifyLdapEntry}
				echo "memberUid: ${computerNewCn}" >> ${groupModifyLdapEntry}
				ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${groupModifyLdapEntry}
				[[ $? -ne 0 ]] && error 10 "Problème lors de la modification de l'attribut 'memberUid: ${oldComputerLocalHostName}' vers 'memberUid: ${computerNewCn}' de l'entrée '${computerGroup}' !"
				rm -R ${groupModifyLdapEntry}
			fi
		done
	fi

	# Ménage pour renommer dans le LDAP les entrées ordinateurs qui ont changé de nom à l'intérieur de liste(s) 
	# Liste des listes dont l'ordinateur est membre
	${ldapCommandBegin} -b ${dnListsComputers},${ldapDnBase} dn >> ${listsOfComputerTemp}
	ldapUnSplitLines "${listsOfComputerTemp}"
	oldIfs=$IFS ; IFS=$'\n'
	for listDn in $(cat ${listsOfComputerTemp})
	do
		base64decode ${listDn} | grep ^dn: | perl -p -e 's/dn: //g' | grep -v ^${dnListsComputers},${ldapDnBase} >> ${listsOfComputerClean}
	done
	IFS=$oldIfs
	# Pour chaque liste
	if [[ ! -z $(cat ${listsOfComputerClean}) ]]; then
		for computerList in $(cat ${listsOfComputerClean})
		do
			${ldapCommandBegin} -b ${computerList} apple-computers | grep ${oldComputerLocalHostName} > /dev/null 2>&1
			# Si le nom ancien existe et qu'il y a un nouveau nom > changement dans le Ldap
			if [[ $? -eq 0 ]] && [[ "${oldComputerLocalHostName}" != "${computerNewCn}" ]]; then
				listModifyLdapEntry=/tmp/renameMacFromOpenDirectory_listModifyLdapEntry.ldif
				[[ -e ${listModifyLdapEntry} ]] && rm -R ${listModifyLdapEntry}
				echo "dn: ${computerList}" > ${listModifyLdapEntry}
				echo "changetype: modify" >> ${listModifyLdapEntry}
				echo "delete: apple-computers" >> ${listModifyLdapEntry}
				echo "apple-computers: ${oldComputerLocalHostName}" >> ${listModifyLdapEntry}
				echo "-" >> ${listModifyLdapEntry}
				echo "add: apple-computers" >> ${listModifyLdapEntry}
				echo "apple-computers: ${computerNewCn}" >> ${listModifyLdapEntry}
				ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${listModifyLdapEntry}
				[[ $? -ne 0 ]] && error 10 "Problème lors de la modification de l'attribut 'apple-computers: ${oldComputerLocalHostName}' vers 'apple-computers: ${computerNewCn}' de l'entrée '${computerList}' !"
				rm -R ${listModifyLdapEntry}
			fi
		done
	fi

	# Ménage pour supprimer les entrées que ne correspondent à aucun ordinateur
	# On génère une liste de tous les utilisateurs
	${ldapCommandBegin} -b ${dnUserBranch},${ldapDnBase} dn >> ${userLdapList}
	ldapUnSplitLines "${userLdapList}"
	oldIfs=$IFS ; IFS=$'\n'
	sed '/^$/d' ${userLdapList} | grep uid >> ${userLdapList}.new
	for lineuid in $(cat ${userLdapList}.new)
	do
		base64decode ${lineuid} >> ${userLdapListDecoded}
	done
	IFS=$oldIfs
	for user in $(cat ${userLdapListDecoded} | grep ^dn: | perl -p -e 's/dn: //g')
	do
		userLdapListWithComputer=$(mktemp /tmp/renameMacFromOpenDirectory_userLdapListWithComputer.XXXXX)
		userLdapListWithComputerDecoded=$(mktemp /tmp/renameMacFromOpenDirectory_userLdapListWithComputerDecoded.XXXXX)
		[[ -e ${userLdapListWithComputer} ]] && rm -R ${userLdapListWithComputer}
		[[ -e ${userLdapListWithComputerDecoded} ]] && rm -R ${userLdapListWithComputerDecoded}
		${ldapCommandBegin} -b ${user} ${attributOwnedComputer} >> ${userLdapListWithComputer}
		ldapUnSplitLines "${userLdapListWithComputer}"
		oldIfs=$IFS ; IFS=$'\n'
		for ligne in $(cat ${userLdapListWithComputer})
		do
			base64decode ${ligne} >> ${userLdapListWithComputerDecoded}
		done
		IFS=$oldIfs
		useruiddn=$(cat ${userLdapListWithComputerDecoded} | grep ^dn: | perl -p -e 's/dn: //g')
		for computerline in $(cat ${userLdapListWithComputerDecoded} | grep ^${attributOwnedComputer}: | sed 's/'"${attributOwnedComputer}: "'//g')
		do
			# Test si l'entrée ordinateur existe
			${ldapCommandBegin} -b ${computerline} > /dev/null 2>&1
			if [[ $? -ne 0 ]] ; then
				[[ -e ${userDeleteOwnedComputer} ]] && rm -R ${userDeleteOwnedComputer}
				[[ ${verbosity} -eq 1 ]] && echo -e "\nL'attribut '${attributOwnedComputer}: ${computerline}' de '${useruiddn}' semble incorrect. Nous allons le supprimer."
				userDeleteOwnedComputer=/tmp/renameMacFromOpenDirectory_userDeleteOwnedComputer.ldif
				[[ -e ${userDeleteOwnedComputer} ]] && rm -R ${userDeleteOwnedComputer}
				echo "dn: ${useruiddn}" > ${userDeleteOwnedComputer}
				echo "changetype: modify" >> ${userDeleteOwnedComputer}
				echo "delete: ${attributOwnedComputer}" >> ${userDeleteOwnedComputer}
				echo "${attributOwnedComputer}: ${computerline}" >> ${userDeleteOwnedComputer}
				ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${userDeleteOwnedComputer}
				[[ $? -ne 0 ]] && error 10 "Problème lors de la suppression de l'attribut '${attributOwnedComputer}: ${computerline}' de l'entrée ${useruiddn} !"
				rm -R ${userDeleteOwnedComputer}
			fi
		done
	done
fi

if [[ ${syncAttributes} = "1" ]] ; then
	if [[ -z ${computerOwner} ]]; then
		[[ ${verbosity} -eq 1 ]] && echo "L'ordinateur n'a pas d'attribut '${attributComputerOwner}' renseigné. La synchronisation des attributs ne peut être réalisée."
	else 
		${ldapCommandBegin} -b ${computerOwner} > /dev/null 2>&1
		if [[ $? -ne 0 ]] ; then
			[[ ${verbosity} -eq 1 ]] && echo "Impossible de renseigner l'attribut ${attributOwnedComputer} pour ${computerOwner}, car cette entrée user semble incorrecte."
		else
			oldOwnersTemp=$(mktemp /tmp/renameMacFromOpenDirectory_oldOwnersTemp.XXXXX)
			oldOwnersTemp2=$(mktemp /tmp/renameMacFromOpenDirectory_oldOwnersTemp2.XXXXX)
			${ldapCommandBegin} -b ${dnUserBranch},${ldapDnBase} ${attributOwnedComputer}=${dnComputer} uid > ${oldOwnersTemp}
			ldapUnSplitLines "${oldOwnersTemp}"
			oldIfs=$IFS ; IFS=$'\n'
			for line in $(cat ${oldOwnersTemp})
			do
				base64decode ${line} | grep ^dn: | perl -p -e 's/dn: //g' >> ${oldOwnersTemp2}
			done
			IFS=$oldIfs
			# Suppression des entrées dans les fiches utilisateurs qui ne sont pas nécessaires
			[[ ${verbosity} -eq 1 ]] && [[ ! -z $(cat ${oldOwnersTemp2} | grep -v ${computerOwner}) ]] && echo "" && echo "Suppression de l'attribut ${attributOwnedComputer} pour les utilisateurs suivants :" && cat ${oldOwnersTemp2} | grep -v ${computerOwner}
			for line in $(cat ${oldOwnersTemp2})
			do
				userDeleteOwnedComputer=/tmp/renameMacFromOpenDirectory_userDeleteOwnedComputer.ldif
				[[ -e ${userDeleteOwnedComputer} ]] && rm -R ${userDeleteOwnedComputer}
				echo "dn: ${line}" > ${userDeleteOwnedComputer}
				echo "changetype: modify" >> ${userDeleteOwnedComputer}
				echo "delete: ${attributOwnedComputer}" >> ${userDeleteOwnedComputer}
				echo "${attributOwnedComputer}: ${dnComputer}" >> ${userDeleteOwnedComputer}
				ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${userDeleteOwnedComputer}
				[[ $? -ne 0 ]] && error 10 "Problème lors de la suppression de l'attribut '${attributOwnedComputer}: ${dnComputer}' de l'entrée ${line} !"
				rm -R ${userDeleteOwnedComputer}
			done
			userAddOwnedComputer=/tmp/renameMacFromOpenDirectory_userAddOwnedComputer.ldif
			[[ -e ${userAddOwnedComputer} ]] && rm -R ${userAddOwnedComputer}
			echo "dn: ${computerOwner}" > ${userAddOwnedComputer}
			echo "changetype: modify" >> ${userAddOwnedComputer}
			echo "add: ${attributOwnedComputer}" >> ${userAddOwnedComputer}
			echo "${attributOwnedComputer}: ${dnComputer}" >> ${userAddOwnedComputer}
			ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${userAddOwnedComputer}
			[[ $? -ne 0 ]] && error 10 "Problème lors de l'ajout de l'attribut '${attributOwnedComputer}: ${dnComputer}' sur l'entrée ${computerOwner} !"
			rm -R ${userAddOwnedComputer}
		fi
	fi
fi

## Ajout de l'audit / inventaire specs en commentaire sur LDAP
if [[ ${addCommentToLdap} = "1" ]]; then
	commentLdapTemp=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapTemp.XXXXX)
	commentLdapOriginal=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapOriginal.XXXXX)
	commentLdapOriginalDecoded=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapOriginalDecoded.XXXXX)
	commentLdapOriginalClean=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapOriginalClean.XXXXX)
	commentLdapOriginalCleanBegin=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapOriginalCleanBegin.XXXXX)
	commentLdapOriginalCleanEnd=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapOriginalCleanEnd.XXXXX)
	commentLdapNew=$(mktemp /tmp/renameMacFromOpenDirectory_commentLdapNew.XXXXX)
	commentLdapAdd=/tmp/renameMacFromOpenDirectory_add.ldif

	# On teste les dossiers
	if [[ ! -e ${scriptsDirCompatibilityCheck} ]]; then
		echo "On créé le dossier ${scriptsDirCompatibilityCheck} pour y installer les scripts de test de compatibilité."
		echo ""
		mkdir -p ${scriptsDirCompatibilityCheck}
		[[ $? -ne 0 ]] && error 1 "Impossible de créer le dossier ${scriptsDirCompatibilityCheck}. Nous quittons."
	fi

	# Suppression des anciennes versions de check scripts
	[[ -e ${scriptDir%/}/check-mountainlion-compatibility.py ]] && rm ${scriptDir%/}/check-mountainlion-compatibility.py
	[[ -e ${scriptDir%/}/check-mavericks-compatibility.py ]] && rm ${scriptDir%/}/check-mavericks-compatibility.py
	[[ -e ${scriptDir%/}/check-yosemite-compatibility.py ]] && rm ${scriptDir%/}/check-yosemite-compatibility.py
	[[ -e ${scriptDir%/}/check-elcapitan-compatibility.py ]] && rm ${scriptDir%/}/check-elcapitan-compatibility.py

	# On installe les sous-scripts s'ils ne le sont pas
	# 10.8
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_8Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_8Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility}
	curl --insecure ${scriptCheckMacOS10_8CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility} 
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility}
	# 10.9
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_9Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_9Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility}
	curl --insecure ${scriptCheckMacOS10_9CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility}
	# 10.10
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_10Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_10Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility}
	curl --insecure ${scriptCheckMacOS10_10CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility}
	# 10.11
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_11Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_11Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility}
	curl --insecure ${scriptCheckMacOS10_11CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility}
	# 10.12
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_12Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_12Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility}
	curl --insecure ${scriptCheckMacOS10_12CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility}
	# 10.13
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_13Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_13Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility}
	curl --insecure ${scriptCheckMacOS10_13CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility}
	# 10.14
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_14Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_14Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility}
	curl --insecure ${scriptCheckMacOS10_14CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility}
	# 10.15
	[[ -e ${scriptDir%/}/${scriptCheckMacOS10_15Compatibility} ]] && rm ${scriptDir%/}/${scriptCheckMacOS10_15Compatibility}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility}
	curl --insecure ${scriptCheckMacOS10_15CompatibilityGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility}
	# Malware check
	[[ -e ${scriptDir%/}/${scriptCheckForMalware} ]] && rm ${scriptDir%/}/${scriptCheckForMalware}
	[[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware} ]] && rm ${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware}
	curl --insecure ${scriptCheckForMalwareGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware}
	# SSD Check - dispose d'un auto-update, pas besoin de le réinstaller à chaque fois
	[[ ! -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckSsd} ]] \
	&& curl --insecure ${scriptCheckSsdGit} --create-dirs -so ${scriptsDirCompatibilityCheck%/}/${scriptCheckSsd}
	chmod +x ${scriptsDirCompatibilityCheck%/}/${scriptCheckSsd}

	# On prépare les données qui vont être intégrées en commentaire
	curl -s https://support-sp.apple.com/sp/product?cc=`ioreg -l | grep "IOPlatformSerialNumber" | cut -d ""="" -f 2 | sed -e s/[^[:alnum:]]//g | cut -c 9-` > /dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		modeleComplet=$(curl -s https://support-sp.apple.com/sp/product?cc=`ioreg -l | grep "IOPlatformSerialNumber" | cut -d ""="" -f 2 | sed -e s/[^[:alnum:]]//g | cut -c 9-` | sed 's|.*<configCode>\(.*\)</configCode>.*|\1|')
	else
		error 9 "Problème de connexion internet lors de la connexion à la base de données Apple.\nMerci de vérifier votre connectivité internet avant de relancer !"
	fi
	processorName=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Processor Name:" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')
	processorSpeed=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Processor Speed:" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')
	processorNumber=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Number of Processors:" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')
	processorCores=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Total Number of Cores:" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')
	memory=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Memory:" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')
	serialNumber=$(/usr/sbin/system_profiler SPHardwareDataType 2> /dev/null | grep "Serial Number (system):" | cut -d "":"" -f 2 | perl -p -e 's/^ //g')

	# Alimentation du fichier LDIF
	echo "########## [${scriptName}] Start ##########" > ${commentLdapTemp}
	echo "" >> ${commentLdapTemp}
	echo "Dernière mise à jour des informations le : `date`" >> ${commentLdapTemp}
	echo "" >> ${commentLdapTemp}
	echo ">>> Informations Hardware ${nomModele}" >> ${commentLdapTemp}
	[[ ! -z ${modeleComplet} ]] && echo "- Modèle : ${modeleComplet}" >> ${commentLdapTemp}
	[[ ! -z ${processorName} ]] && echo "- Processeur : ${processorName}" >> ${commentLdapTemp}
	[[ ! -z ${processorSpeed} ]] && echo "- Vitesse processeur : ${processorSpeed}" >> ${commentLdapTemp}
	[[ ! -z ${processorNumber} ]] && echo "- Nombre de processeur(s) : ${processorNumber}" >> ${commentLdapTemp}
	[[ ! -z ${processorCores} ]] && echo "- Nombre de coeurs : ${processorCores}" >> ${commentLdapTemp}
	[[ ! -z ${memory} ]] && echo "- Mémoire vive : ${memory}" >> ${commentLdapTemp}
	[[ ${detailModeleEcran} -eq 1 ]] && [[ ${detailModeleRetina} -ne 1 ]] && echo "- Taille écran : ${detailModeleTailleEcran}'" >> ${commentLdapTemp}
	[[ ${detailModeleEcran} -eq 1 ]] && [[ ${detailModeleRetina} -eq 1 ]] && echo "- Taille écran : ${detailModeleTailleEcran}' Retina" >> ${commentLdapTemp}
	[[ ! -z ${serialNumber} ]] && echo "- Numéro série machine : ${serialNumber}" >> ${commentLdapTemp}
	[[ ! -z ${hwuuid} ]] && echo "- UUID Machine : ${hwuuid}" >> ${commentLdapTemp}
	echo "" >> ${commentLdapTemp}
	echo ">>> Informations Système" >> ${commentLdapTemp}
	echo "- Mac OS X version $(sw_vers -productVersion)" >> ${commentLdapTemp}
	echo "" >> ${commentLdapTemp}
	echo ">>> Autres informations" >> ${commentLdapTemp}
	[[ ! -z ${dnComputer} ]] && echo "- DN Computer (dnComputer) : ${dnComputer}" >> ${commentLdapTemp}
	[[ ! -z ${computerNewRealName} ]] && echo "- ComputerName (computerNewRealName) : ${computerNewRealName}" >> ${commentLdapTemp}
	[[ ! -z ${computerNewCn} ]] && echo "- ComputerName (computerNewCn) : ${computerNewCn}" >> ${commentLdapTemp}
	[[ ! -z ${computerOwnerCN} ]] && echo "- ComputerOwnerCN : ${computerOwnerCN}" >> ${commentLdapTemp}
	[[ ! -z ${computerOwnerDN} ]] && echo "- ComputerOwnerDN : ${computerOwnerDN}" >> ${commentLdapTemp}
	echo "" >> ${commentLdapTemp}
	if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility} ]] || [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility} ]] || [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility} ]] || [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility} ]]; then
		echo ">>> Compatibilité OS" >> ${commentLdapTemp}
		oldIfs=$IFS ; IFS=$'\n'
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility} ]]; then
			echo "- check-mountainlion-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_8Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility} ]]; then
			echo "- check-mavericks-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_9Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility} ]]; then
			echo "- check-yosemite-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_10Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility} ]]; then
			echo "- check-elcapitan-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_11Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility} ]]; then
			echo "- check-sierra-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_12Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility} ]]; then
			echo "- check-high-sierra-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_13Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility} ]]; then
			echo "- check-mojave-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_14Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility} ]]; then
			echo "- check-catalina-compatibility :" >> ${commentLdapTemp}
			for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckMacOS10_15Compatibility} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		fi
		IFS=$oldIfs
		echo "" >> ${commentLdapTemp}
	fi
	if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware} ]]; then
		oldIfs=$IFS ; IFS=$'\n'
		echo ">>> Recherche Malware avec ${scriptCheckForMalware} :" >> ${commentLdapTemp}
		for line in $(${scriptsDirCompatibilityCheck%/}/${scriptCheckForMalware} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		IFS=$oldIfs
		echo "" >> ${commentLdapTemp}
	fi
	if [[ -e ${scriptsDirCompatibilityCheck%/}/${scriptCheckSsd} ]]; then
		oldIfs=$IFS ; IFS=$'\n'
		echo ">>> Vérification SSD / TRIM avec ${scriptCheckSsd} :" >> ${commentLdapTemp}
		for line in $(exec ${scriptsDirCompatibilityCheck%/}/${scriptCheckSsd} | tr -s ' '); do echo -e "\t${line}" >> ${commentLdapTemp}; done
		IFS=$oldIfs
		echo "" >> ${commentLdapTemp}
	fi
	echo "########### [${scriptName}] End ###########" >> ${commentLdapTemp}

	# On récupère le contenu actuel du champ commentaire
	${ldapCommandBegin} -b ${dnComputerBranch},${ldapDnBase} ${cnComputer} ${attributComment} > ${commentLdapOriginal}
	ldapUnSplitLines "${commentLdapOriginal}"
	oldIfs=$IFS ; IFS=$'\n'
	for line in $(cat ${commentLdapOriginal})
	do
		base64decode ${line} >> ${commentLdapOriginalDecoded}
	done
	IFS=$oldIfs
	# On génère un export clean ne contenant que le champ contenu
	cat ${commentLdapOriginalDecoded} | sed '/'"${dnComputer}"'/d' | sed 's/'"${attributComment}: "'//g' >> ${commentLdapOriginalClean}
	# On vérifie si il y a déjà un commentaire
	grep '########## \['"${scriptName}"'\] Start ##########' ${commentLdapOriginalClean} > /dev/null 2>&1
	[[ $? -eq 0 ]] && ligneDebut=$(sed -n '/########## \['"${scriptName}"'\] Start ##########/=' ${commentLdapOriginalClean})
	grep '########### \['"${scriptName}"'\] End ###########' ${commentLdapOriginalClean} > /dev/null 2>&1
	[[ $? -eq 0 ]] && ligneFin=$(sed -n '/########### \['"${scriptName}"'\] End ###########/=' ${commentLdapOriginalClean})
	[[ ${ligneDebut} -gt 1 ]] && head -n $((${ligneDebut}-1)) ${commentLdapOriginalClean} >> ${commentLdapOriginalCleanBegin}
	[[ ${ligneFin} -ne 0 ]] && tail -n $(($(sed -n '$=' ${commentLdapOriginalClean})-${ligneFin})) ${commentLdapOriginalClean} >> ${commentLdapOriginalCleanEnd}

	# On exporte le nouveau commentaire
	[[ ${ligneDebut} -eq 0 ]] && cat ${commentLdapOriginalClean} >> ${commentLdapNew} && echo "" >> ${commentLdapNew} && cat ${commentLdapTemp} >> ${commentLdapNew}
	[[ ${ligneDebut} -ne 0 ]] && cat ${commentLdapOriginalCleanBegin} >> ${commentLdapNew} && cat ${commentLdapTemp} >> ${commentLdapNew}
	[[ ${ligneDebut} -ne 0 ]] && [[ $(($(sed -n '$=' ${commentLdapOriginalClean})-${ligneFin})) -ne 0 ]] && cat ${commentLdapOriginalCleanEnd} >> ${commentLdapNew}

	[[ ${verbosity} -eq 1 ]] && [[ ! -z $(cat ${commentLdapOriginalClean}) ]] && echo "" && echo "Contenu précédent du commentaire :" && cat ${commentLdapOriginalClean} && echo ""
	[[ ${verbosity} -eq 1 ]] && [[ -z $(cat ${commentLdapOriginalClean}) ]] && echo "Fichier initial de commentaire de l'entrée LDAP ${commentLdapOriginalClean} vide." && echo ""

	# On applique la modification sur le LDAP
	# Modification du commentaire : modification du commentaire
	echo "dn: ${dnComputer}" > ${commentLdapAdd}
	echo "changetype: modify" >> ${commentLdapAdd}
	echo "replace: ${attributComment}" >> ${commentLdapAdd}
	if [[ $(awk 'END {print NR}' ${commentLdapNew}) -gt 1 ]]; then
		echo "${attributComment}:: $(openssl enc -base64 -in ${commentLdapNew} | perl -p -e 's/\n//g')" >> ${commentLdapAdd}
	else
		echo "${attributComment}: $(head -n 1 ${commentLdapNew})" >> ${commentLdapAdd}
	fi
	[[ ${verbosity} -eq 1 ]] && echo "Modification appliquée au LDAP (fichier ldif) :" && cat ${commentLdapAdd} && echo ""
	ldapmodify -H ${ldapUrl} -D uid=${ldapAdminUid},${dnUserBranch},${ldapDnBase} -w ${ldapAdminPass} -x -f ${commentLdapAdd}
	[[ $? -ne 0 ]] && error 10 "Problème lors de la modification de l'attribut ${attributComment} de l'entrée ${dnComputer} !"
fi

alldone 0