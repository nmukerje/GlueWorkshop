##
## glue-sagemaker-lifecycle.sh
##
#!/bin/bash
set -ex
if ! [ -e /home/ec2-user/glue_ready ]; then

    mkdir -p /home/ec2-user/glue
    cd /home/ec2-user/glue

    #GLUE_ENDPOINT and ASSETS must be set by the consumer of this script
    REGION=$(aws configure get region)

    # Write dev endpoint in a file which will be used by daemon scripts
    glue_endpoint_file="/home/ec2-user/glue/glue_endpoint.txt"

    if [ -f $glue_endpoint_file ] ; then
        rm $glue_endpoint_file
    fi
    echo "https://glue.$REGION.amazonaws.com" >> $glue_endpoint_file

    ASSETS=s3://aws-glue-jes-prod-$REGION-assets/sagemaker/assets/

    aws s3 cp ${ASSETS} . --recursive

    bash "/home/ec2-user/glue/Miniconda2-4.5.12-Linux-x86_64.sh" -b -u -p "/home/ec2-user/glue/miniconda"

    source "/home/ec2-user/glue/miniconda/bin/activate"

    tar -xf autossh-1.4e.tgz
    cd autossh-1.4e
    ./configure
    make
    sudo make install
    sudo cp /home/ec2-user/glue/autossh.conf /etc/init/

    mkdir -p /home/ec2-user/.sparkmagic
    cp /home/ec2-user/glue/config.json /home/ec2-user/.sparkmagic/config.json

    mkdir -p /home/ec2-user/SageMaker/Glue\ Examples
    mv /home/ec2-user/glue/notebook-samples/* /home/ec2-user/SageMaker/Glue\ Examples/

    # Run daemons as cron jobs and use flock make sure that daemons are started only iff stopped
    (crontab -l; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-v2-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-v2-dev-endpoint-daemon.sh") | crontab -

    (crontab -l; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-reconnect-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-reconnect-dev-endpoint-daemon.sh") | crontab -

    source "/home/ec2-user/glue/miniconda/bin/deactivate"

    rm -rf "/home/ec2-user/glue/Miniconda2-4.5.12-Linux-x86_64.sh"

    sudo touch /home/ec2-user/glue_ready
fi

# Download and save stack-info python script
aws s3 cp s3://emr-workshops-us-west-2/glue_immersion_day/scripts/sagemaker-glue-get-stack-info.py /home/ec2-user/scripts/
chmod +x /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py
python /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py

# Copy sample notebooks
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/notebooks/ /home/ec2-user/SageMaker

s3_bucket=`cat stack-info.json | jq -r .S3Bucket`
echo "s3_bucket : $s3_bucket"

## Replace tokens in Notebook
sed -i "s/###s3_bucket###/$s3_bucket/" /home/ec2-user/SageMaker/1_Building_a_DataLake_using_AWS_Glue.ipynb

## Copy the data
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/data/ s3://$s3_bucket/data/

## Copy the scripts
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/scripts/ s3://$s3_bucket/scripts/
