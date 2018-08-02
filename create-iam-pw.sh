#!/usr/bin/env bash
#---------------------------------------------------#
#     <Christopher Stobie> cjstobie@gmail.com
#---------------------------------------------------#

spacer(){
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
} 

help_func(){
    spacer
    echo "Required positional parameters"
    spacer
    echo "1: AWS CLI Profile Name"
    echo "2: IAM Username to setup"
    echo "3: Users email to send login instructions to"
    spacer
    echo "Example Usage"
    spacer
    echo "./create-iam-pw.sh coolprofilename myuser myuser@domain.com"
    spacer
}

aws_com(){
    aws "$@" --profile ${profile}
}

get_vars(){
    profile="$1"
    u_name="$2"
    u_email="$3"

    if [[ -z ${u_name} || -z ${u_email} ]]; then
        spacer
        echo "Must pass username and email address"
        help_func
        exit 1
    fi

    if [[ -z $profile ]]; then
        echo "Missing required variable: AWS CLI profile to use"
        exit 1
    fi

    #---------------------------------------------------#  
    # These must be set before the script will work
    #---------------------------------------------------#  
    bucket_name=""
    from_email=""
    reply_email=""

    if [[ -z ${bucket_name} || -z ${from_email} || -z ${reply_email} ]]; then
        echo "Missing required variables, please update the script and define the following vars"
        echo "bucket_name"
        echo "from_email"
        echo "reply_email"
        echo "Please modify this script and enter these variables"
        exit 1
    fi

    account_number=$(aws_com sts get-caller-identity --output text --query 'Account')
    if [[ -z ${account_number} ]]; then
        echo "Unable to get account number from STS"
        exit 1
    fi
}

put_pw_s3(){
    pass="$(openssl rand -base64 16)"
    uuid=$(uuidgen)
    echo "${pass}" | aws s3 cp - s3://${bucket_name}/${uuid}/pw.txt --profile ${profile} 
    s3_link=$(aws s3 presign s3://${bucket_name}/${uuid}/pw.txt --expires-in 86400 --profile ${profile})
}

send_email(){
    email_content="<html><h3>Hello ${u_name} and welcome to AWS!</h3>
<p>Your temporary password can be found <a href="${s3_link}">here</a>. Your username is ${u_name}. You will be required to reset your password on first login.</p>
<p>Please be sure to setup MFA once you have successfully logged in,&nbsp;<a href="https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable.html">instructions here.</a></p>
<p>Login to the AWS Console with account ID: ${account_number}.</p>
<p>Please email ${reply_email} if you have any questions.</p>
<p>Thanks!</p>
</html>
"
    aws ses send-email --from "${from_email}" --reply-to-addresses "${reply_email}" --to ${u_email} --subject "AWS Account Setup" --html "${email_content}"  --profile ${profile}
}

create_pass(){
    aws_com iam create-login-profile \
        --user-name ${u_name} \
        --password ${pass} \
        --password-reset-required 
}

check_exists(){
    #---------------------------------------------------#  
    # Test to see if the user already has a login
    # profile, if so discontinue script
    #---------------------------------------------------#  
    aws_com iam get-login-profile --user-name ${u_name} 2>&1 | jq -r '.LoginProfile.UserName' &>/dev/null
}

delete_login_profile(){
    aws_com iam delete-login-profile --user-name ${u_name}
}

main(){
    get_vars "$@"

    if check_exists; then
        read -p "User already has a login profile, press enter to delete and reset password or cntl^c to abort. "
        delete_login_profile
    fi

    put_pw_s3

    if create_pass; then
        send_email
    fi
}

main "$@"
