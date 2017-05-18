
VPATH = ./cf4

CFTGEN = cftgen
TEXT2JL = text2jl

# provision_aws conf files
# they are created from the conf/ directory!

CONF_FILES = sncrbda-dev.conf sncrbda-dev-add1.conf \
	sncrbda-dev-rt.conf sncrbda-dev-rt-add1.conf \
	sncrbda-qa.conf \
	sncrbda-prod.conf sncrbda-prod-perf.conf sncrbda-poc.conf sncrbda-mct-prod.conf sncrbda-mct-qa.conf

# add additional subnet cf4 sources here
# remember to add their map files as dependencies (far) below

SUBNETS_CFT = network-subnets-dev.cft  network-subnets-qa.cft network-subnets-prod.cft

APP_SGS_CFT = xdf-node-sg.cft mapr-console-sg.cft esap-console-sg.cft

all: 	$(CONF_FILES) \
	$(SUBNETS_CFT) \
	$(APP_SGS_CFT) \
	iam-groups.cft iam-roles.cft iam-logicmon.cft \
	s3-buckets.cft \
	cloudwatch.cft cloudtrail.cft \
	network-vpc.cft network-acls.cft \
	network-routing.cft \
	network-route53.cft \
	network-sgs.cft \
	simple-elb.cft \
	server.cft server-small.cft server-8e.cft \
	nat-server.cft nat-sg.cft \
	network-natgateway.cft \
	ec2-placementgroup.cft \
	xdf-access.cft

iam-groups.cft: iam-groups.cf4

iam-roles.cft: iam-roles.cf4

iam-logicmon.cft: iam-logicmon.cf4

s3-buckets.cft: s3-buckets.cf4

cloudwatch.cft: cloudwatch.cf4

cloudtrail.cft: cloudtrail.cf4

network-route53.cft: network-route53.cf4

network-routing.cft: network-routing.cf4

network-vpc.cft: network-vpc.cf4

network-acls.cft: network-acls.cf4 sncr-cidrs.m4

network-subnets-dev.cft: network-subnets-dev.cf4 subnets-dev.map

network-subnets-qa.cft: network-subnets-qa.cf4 subnets-qa.map

network-subnets-prod.cft: network-subnets-prod.cf4 subnets-prod.map

network-sgs.cft: network-sgs.cf4 sncr-cidrs.m4

ec2-placementgroup.cft: ec2-placementgroup.cf4

simple-elb.cft: simple-elb.cf4

nat-sg.cft: nat-sg.cf4 \
	cf4/sncr-cidrs.m4

nat-server.cft: nat-server.cf4 \
	cf4/BandwidthPerInstanceType.map \
	cf4/userdata-nat-chef-client.sh.jl

server.cft: server.cf4 \
	cf4/userdata-chef-client.sh.jl

server-small.cft: server.cf4 \
	cf4/userdata-chef-client.sh.jl
	$(CFTGEN) -D NVOLUMES=4 -D NEPHEMS=2 $< > .bad-$@ && mv .bad-$@ $@

server-8e.cft: server.cf4 \
	cf4/userdata-chef-client.sh.jl
	$(CFTGEN) -D NEPHEMS=8 $< > .bad-$@ && mv .bad-$@ $@

xdf-access.cft: xdf-access.cf4 \
	cf4/sncr-cidrs.m4

ec2-placementgroup.cft: ec2-placementgroup.cf4

mapr-console-sg.cft: mapr-console-sg.cf4 sncr-cidrs.m4
esap-console-sg.cft: esap-console-sg.cf4 sncr-cidrs.m4

test-server-sg.cft: test-server-sg.cf4

#
# --- userdata script (conversion) targets
#

cf4/userdata-chef-client.sh.jl: cf4/userdata-chef-client.sh
	$(TEXT2JL) cf4/userdata-chef-client.sh > cf4/userdata-chef-client.sh.jl

cf4/userdata-nat-chef-client.sh.jl: cf4/userdata-nat-chef-client.sh
	$(TEXT2JL) cf4/userdata-nat-chef-client.sh > cf4/userdata-nat-chef-client.sh.jl


# provision-aws conf files

CONF_DEFAULTS = conf/sncrbda-defaults.incf
sncrbda-dev.conf: conf/sncrbda-dev.incf $(CONF_DEFAULT)
sncrbda-dev-add1.conf: conf/sncrbda-dev-add1.incf $(CONF_DEFAULT)
sncrbda-poc.conf: conf/sncrbda-poc.incf $(CONF_DEFAULT)
sncrbda-dev-rt.conf: conf/sncrbda-dev-rt.incf $(CONF_DEFAULT)
sncrbda-dev-rt-add1.conf: conf/sncrbda-dev-rt-add1.incf $(CONF_DEFAULT)
sncrbda-mct-prod.conf: conf/sncrbda-mct-prod.incf $(CONF_DEFAULT)
sncrbda-mct-qa.conf: conf/sncrbda-mct-qa.incf $(CONF_DEFAULT)

sncrbda-qa.conf: conf/sncrbda-qa.incf $(CONF_DEFAULT)

sncrbda-prod.conf: conf/sncrbda-prod.incf $(CONF_DEFAULT)
sncrbda-prod-perf.conf: conf/sncrbda-prod-perf.incf $(CONF_DEFAULT)

#
# --- validation targets
#

validate: validate-templates validate-userdata validate-bootstrap

# validate a copy of each template with leading spaces removed

validate-templates: all
	@echo "-- validating cf templates"
	@fail=0; > validate.out ; \
	for x in *.cft; do \
	  cat $$x | sed 's/^ *//' > /tmp/$$x.$$$$ ; \
	  aws cloudformation validate-template \
		--template-body file:///tmp/$$x.$$$$ >> validate.out 2>&1; \
	  rc=$$?; echo $$x $$rc; \
	  rm -f /tmp/$$x.$$$$; \
	  if [ $$rc != 0 ]; then fail=1 ; fi ;\
	done ; \
	if [ $$fail != 0 ]; then echo "TEMPLATE VALIDATON FAILED" ; exit 1 ; fi

validate-userdata: all
	@echo "-- validating userdata shell scripts"
	@fail=0 ; \
	for x in cf4/*.sh; do \
	  bash -n $$x ; \
	  rc=$$?; \
	  echo $$x $$rc ; \
	  if [ $$rc != 0 ]; then fail=1 ; fi \
	done ; \
	if [ $$fail != 0 ]; then echo "USERDATA VALIDATON FAILED" ; exit 1 ; fi

validate-bootstrap: all
	@echo "-- validating bootstrap shell scripts"
	@fail=0 ; \
	for x in bootstrap/*.sh; do \
	  bash -n $$x ; \
	  rc=$$?; \
	  echo $$x $$rc ; \
	  if [ $$rc != 0 ]; then fail=1 ; fi \
	done ; \
	if [ $$fail != 0 ]; then echo "BOOTSTRAP SCRIPT VALIDATON FAILED" ; exit 1 ; fi

#
# --- clean targets
#

clean:
	rm -f *.cft *~

#
# --- misc
#

.SUFFIXES: .cf4 .cft .sh .jl
.PHONY: all clean \
	validate validate-templates validate-userdata validate-bootstrap


#
# -- implicit rules
#

%.cft: %.cf4
	$(CFTGEN) $< > .bad-$@ && mv .bad-$@ $@

%.conf: conf/%.incf $(CONF_DEFAULTS)
	@echo "Creating $@ configuration file"
	@echo "# -- DO NOT EDIT -- AUTOMATICALLY GENERATED" | \
		cat - $(CONF_DEFAULTS) $< > $@
