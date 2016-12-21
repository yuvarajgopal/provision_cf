
VPATH = ./cf4

CFTGEN = cftgen

# add additional subnet cf4 sources here
# remmeber to add their map files as dependencies (far) below

SUBNETS_CFT = network-subnets-dev.cft

all: 	iam-groups.cft iam-roles.cft \
	s3-buckets.cft \
	cloudwatch.cft \
	network-route53.cft \
	network-vpc.cft network-acls.cft \
	network-routing.cft  \
	network-route53.cft \
	$(SUBNETS_CFT) \
	network-sgs.cft \
	ec2-placementgroup.cft \
	chef-server.cft chef-squid-proxy.cft \
	server.cft server-small.cft server-8e.cft \
	nat-sg.cft nat-server.cft \
	test-server-sg.cft \
	elasticsearch-sg.cft

iam-groups.cft: iam-groups.cf4

iam-roles.cft: iam-roles.cf4

s3-buckets.cft: s3-buckets.cf4

cloudwatch.cft: cloudwatch.cf4

network-route53.cft: network-route53.cf4

network-vpc.cft: network-vpc.cf4

network-acls.cft: network-acls.cf4 sncr-cidrs.m4

network-routing.cft: network-routing.cf4

network-subnets-dev.cft: network-subnets-dev.cf4 cf4/subnets-dev.map

network-sgs.cft: network-sgs.cf4

ec2-placementgroup.cft: ec2-placementgroup.cf4

chef-server.cft: chef-server.cf4 \
	cf4/userdata-chef-server.sh.jl

chef-squid-proxy.cft: chef-squid-proxy.cf4 \
	cf4/userdata-chef-client.sh.jl \
	cf4/BandwidthPerInstanceType.map

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


test-server-sg.cft: test-server-sg.cf4


elasticsearch-sg.cft: elasticsearch-sg.cf4

#
# --- userdata script (conversion) targets
#

cf4/userdata-chef-server.sh.jl: cf4/userdata-chef-server.sh
	text2jl cf4/userdata-chef-server.sh > cf4/userdata-chef-server.sh.jl

cf4/userdata-chef-client.sh.jl: cf4/userdata-chef-client.sh
	text2jl cf4/userdata-chef-client.sh > cf4/userdata-chef-client.sh.jl

cf4/userdata-nat-chef-client.sh.jl: cf4/userdata-nat-chef-client.sh
	text2jl cf4/userdata-nat-chef-client.sh > cf4/userdata-nat-chef-client.sh.jl

#
# --- validation targets
#

validate: validate-templates validate-userdata

# validate a copy of each template with leading spaces removed

validate-templates: all
	@echo "-- validating cf templates"
	@fail=0; \
	for x in *.cft; do \
	  cat $$x | sed 's/^ *//' > /tmp/$$x.$$$$ ; \
	  aws cloudformation validate-template \
		--template-body file:///tmp/$$x.$$$$ > /dev/null 2>&1; \
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

#
# --- clean targets
#

clean:
	rm -f *.cft *~

#
# --- misc
#

.SUFFIXES: .cf4 .cft .sh .jl
.PHONY: clean validate validate-templates validate-userdata

#
# -- implicit rules
#

%.cft: %.cf4
	$(CFTGEN) $< > .bad-$@ && mv .bad-$@ $@
