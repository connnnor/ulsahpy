cp aws_image.txt pipeline/production
cd pipeline/production
terraform init
terraform apply \
  -var aws_image="$(<aws_image.txt)" \
  -auto-approve \
  -no-color
terraform output -raw ulsahpy-elb-dnsname > ../../elb_dnsname.txt
