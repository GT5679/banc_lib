
fName=$1;
Default_Operator=IOWIZMI;
Operator=${Default_Operator};

xmlstarlet_found=$(which xmlstarlet);
if [[ "${xmlstarlet_found}" == "" ]]
then 
    echo "Warning \"xmlstarlet\" tool not found. Default Operator is \"${Operator}\".";
else
    Operator=$(xmlstarlet sel -t -v '//InputTeleoperation/Operator' -n ${fName});
fi;

# ----
request="http://iowizmi.westeurope.cloudapp.azure.com:8101/SC06/${Operator}";
echo "From : ${fName}";
echo "Request : ${request}";

# ----
curl -L -X POST ${request} -H 'Content-Type: application/xml' -d @${fName};
