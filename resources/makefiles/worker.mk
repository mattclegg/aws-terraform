#this_make := $(lastword $(MAKEFILE_LIST))
#$(warning $(this_make))

worker: etcd plan_worker
	cd $(BUILD); $(TF_APPLY);
	@$(MAKE) get_etcd_ips
	@$(MAKE) get_worker_ips

plan_worker: init_worker
	cd $(BUILD); $(TF_PLAN)

worker_key:
	cd $(BUILD); \
		$(SCRIPTS)/aws-keypair.sh -c worker; \

plan_destroy_worker:
	$(eval TMP := $(shell mktemp -d -t worker ))
	mv $(BUILD)/worker*.tf $(TMP)
	cd $(BUILD); $(TF_PLAN)
	mv  $(TMP)/worker*.tf $(BUILD)
	rmdir $(TMP)

destroy_worker:  
	rm -f $(BUILD)/worker*.tf
	cd $(BUILD); $(TF_APPLY) 
	$(SCRIPTS)/aws-keypair.sh -d worker;

init_worker: init_etcd init_iam
	cp -rf $(RESOURCES)/terraforms/worker.tf $(RESOURCES)/terraforms/vpc-subnet-worker.tf $(BUILD)
	cd $(BUILD); $(TF_GET); \
	$(SCRIPTS)/aws-keypair.sh -c worker

# Call this explicitly to re-load user_data
update_worker_user_data:
	cd $(BUILD); \
		${TF_TAINT} aws_s3_bucket_object.worker_cloud_config ; \
		$(TF_APPLY)

# EFS has to be enabled for the account
init_efs_target:
	cp -rf $(RESOURCES)/terraforms/worker-efs-targe.tf $(RESOURCES)/terraforms/worker-efs-target $(BUILD)
	cd $(BUILD); $(TF_GET);

get_worker_ips:
	@echo "worker public ips: " `$(SCRIPTS)/get-ec2-public-id.sh worker`

.PHONY: init_worker init_efs_target get_worker_ips destroy_worker 
.PHONT: plan_destroy_worker plan_worker update_worker_user_data worker worker_key

