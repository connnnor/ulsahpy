cp aws_image.txt pipeline/testing 
cd pipeline/testing
terraform init
terraform apply \
  -var aws_image="$(<aws_image.txt)" \
  -auto-approve \
  -no-color
terraform output -raw ulsahpy-test-ip > ../../ec2_ip.txt
