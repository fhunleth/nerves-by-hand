################################################################################
#
# nerves-erlang
#
################################################################################

NERVES_ERLANG_VERSION = 29.0.6
NERVES_ERLANG_RELEASE = $(firstword $(subst ., ,$(NERVES_ERLANG_VERSION)))
NERVES_ERLANG_SITE = \
	https://github.com/erlang/otp/releases/download/OTP-$(NERVES_ERLANG_VERSION)
NERVES_ERLANG_SOURCE = otp_src_$(NERVES_ERLANG_VERSION).tar.gz
NERVES_ERLANG_DEPENDENCIES = host-nerves-erlang

NERVES_ERLANG_LICENSE = Apache-2.0
NERVES_ERLANG_LICENSE_FILES = LICENSE.txt
NERVES_ERLANG_CPE_ID_VENDOR = erlang
NERVES_ERLANG_CPE_ID_PRODUCT = erlang\/otp
NERVES_ERLANG_INSTALL_STAGING = YES

define NERVES_ERLANG_FIX_AUTOCONF_VERSION
	$(SED) "s/USE_AUTOCONF_VERSION=.*/USE_AUTOCONF_VERSION=$(AUTOCONF_VERSION)/" $(@D)/otp_build
endef

# Patched erts/aclocal.m4
define NERVES_ERLANG_RUN_AUTOCONF
	cd $(@D) && PATH=$(BR_PATH) ./otp_build update_configure --no-commit
endef
NERVES_ERLANG_DEPENDENCIES += host-autoconf
NERVES_ERLANG_PRE_CONFIGURE_HOOKS += \
	NERVES_ERLANG_FIX_AUTOCONF_VERSION \
	NERVES_ERLANG_RUN_AUTOCONF
HOST_NERVES_ERLANG_DEPENDENCIES += host-autoconf
HOST_NERVES_ERLANG_PRE_CONFIGURE_HOOKS += \
	NERVES_ERLANG_FIX_AUTOCONF_VERSION \
	NERVES_ERLANG_RUN_AUTOCONF

# Return the EIV (Erlang Interface Version, EI_VSN)
# $(1): base directory, i.e. either $(HOST_DIR) or $(STAGING_DIR)/usr
nerves_erlang_ei_vsn = `sed -r -e '/^erl_interface-(.+)/!d; s//\1/' $(1)/lib/erlang/releases/$(NERVES_ERLANG_RELEASE)/installed_application_versions`

# The configure checks for these functions fail incorrectly
NERVES_ERLANG_CONF_ENV = ac_cv_func_isnan=yes ac_cv_func_isinf=yes

# Set erl_xcomp variables. See xcomp/erl-xcomp.conf.template
# for documentation.
NERVES_ERLANG_CONF_ENV += erl_xcomp_sysroot=$(STAGING_DIR)

NERVES_ERLANG_CONF_OPTS = --without-javac

ifeq ($(BR2_REPRODUCIBLE),y)
NERVES_ERLANG_CONF_OPTS += --enable-deterministic-build
endif

# Force ERL_TOP to the downloaded source directory. This prevents
# Erlang's configure script from inadvertently using files from
# a version of Erlang installed on the host.
NERVES_ERLANG_CONF_ENV += ERL_TOP=$(@D)
HOST_NERVES_ERLANG_CONF_ENV += ERL_TOP=$(@D)

# erlang uses openssl for all things crypto. Since the host tools (such as
# rebar) uses crypto, we need to build host-erlang with support for openssl.
HOST_NERVES_ERLANG_DEPENDENCIES += host-openssl
HOST_NERVES_ERLANG_CONF_OPTS = --without-javac --with-ssl=$(HOST_DIR)

HOST_NERVES_ERLANG_CONF_OPTS += --without-termcap

ifeq ($(BR2_PACKAGE_NCURSES),y)
NERVES_ERLANG_CONF_OPTS += --with-termcap
NERVES_ERLANG_DEPENDENCIES += ncurses
else
NERVES_ERLANG_CONF_OPTS += --without-termcap
endif

ifeq ($(BR2_PACKAGE_OPENSSL),y)
NERVES_ERLANG_CONF_OPTS += --with-ssl
NERVES_ERLANG_DEPENDENCIES += openssl
else
NERVES_ERLANG_CONF_OPTS += --without-ssl
endif

ifeq ($(BR2_PACKAGE_UNIXODBC),y)
NERVES_ERLANG_DEPENDENCIES += unixodbc
NERVES_ERLANG_CONF_OPTS += --with-odbc
else
NERVES_ERLANG_CONF_OPTS += --without-odbc
endif

# Always use Buildroot's zlib
NERVES_ERLANG_CONF_OPTS += --disable-builtin-zlib
NERVES_ERLANG_DEPENDENCIES += zlib

# Remove source, example, gs and wx files from staging and target.
NERVES_ERLANG_REMOVE_PACKAGES = gs wx

ifneq ($(BR2_PACKAGE_NERVES_ERLANG_MEGACO),y)
NERVES_ERLANG_REMOVE_PACKAGES += megaco
endif

define NERVES_ERLANG_REMOVE_STAGING_UNUSED
	for package in $(NERVES_ERLANG_REMOVE_PACKAGES); do \
		rm -rf $(STAGING_DIR)/usr/lib/erlang/lib/$${package}-*; \
	done
endef

define NERVES_ERLANG_REMOVE_TARGET_UNUSED
	find $(TARGET_DIR)/usr/lib/erlang -type d -name src -prune -exec rm -rf {} \;
	find $(TARGET_DIR)/usr/lib/erlang -type d -name examples -prune -exec rm -rf {} \;
	for package in $(NERVES_ERLANG_REMOVE_PACKAGES); do \
		rm -rf $(TARGET_DIR)/usr/lib/erlang/lib/$${package}-*; \
	done
endef

NERVES_ERLANG_POST_INSTALL_STAGING_HOOKS += NERVES_ERLANG_REMOVE_STAGING_UNUSED
NERVES_ERLANG_POST_INSTALL_TARGET_HOOKS += NERVES_ERLANG_REMOVE_TARGET_UNUSED

$(eval $(autotools-package))
$(eval $(host-autotools-package))
