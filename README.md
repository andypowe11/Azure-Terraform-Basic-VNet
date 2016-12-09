# Azure Terraform Basic Virtual Network

Minimal virtual network with 1 public subnet, 3 private networks and an Ubuntu-based NAT box in the public subnet.

Edit settings in vnetvars.tf.

Deploy with:

    terraform plan
    terraform apply
    
Delete everything with:

    terraform destroy

Add the files in 'extras' to deploy a single Ubuntu web server running nginx into the first private subnet and a
load-balancer to provide access to it.
