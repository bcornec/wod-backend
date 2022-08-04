#!/bin/bash

set -e

# redirect stdout/stderr to a file
mkdir -p $HOME/.mail
exec &> >(tee $HOME/.mail/install.log)

date

export WODTYPE=$1
if [ -z "$WODTYPE" ]; then
	echo "Syntax: install_system server|backend|frontend"
	exit -1
fi

if [ ! -f $HOME/.gitconfig ]; then
	cat > $HOME/.gitconfig << EOF
# This is Git's per-user configuration file.
[user]
# Please adapt and uncomment the following lines:
name = jupyter
email = jupyter@nowhere.org
EOF
fi

SCRIPT=`realpath $0`
SCRIPTDIR=`dirname $SCRIPT`

if [ $WODTYPE = "backend" ]; then
	# In case of update remove first old jupyterhub version
	sudo rm -rf /opt/jupyterhub
fi

cat > $SCRIPTDIR/wod.sh << EOF
# This main dir is computed
export WODBEDIR=`dirname $SCRIPTDIR`
EOF
cat >> $SCRIPTDIR/wod.sh << 'EOF'
# These 3 dirs have fixed names by default that you can change in this file
# they are placed as sister dirs wrt WODBEDIR
PWODBEDIR=`dirname $WODBEDIR`
export WODPRIVDIR=$PWODBEDIR/wod-private
export WODSRVDIR=$PWODBEDIR/wod-server
export WODFEDIR=$PWODBEDIR/wod-frontend
WODANSOPT=""
# Manages private inventory if any
if [ -f $WODPRIVDIR/ansible/inventory ]; then
	WODANSOPT="-i $WODPRIVDIR/ansible/inventory"
	export WODANSOPT
fi
EOF
if [ $WODTYPE = "backend" ]; then
	cat >> $SCRIPTDIR/wod.sh << 'EOF'
# This dir is also fixed by default and can be changed as needed
export WODNOBO=$PWODBEDIR/wod-notebooks
export STUDDIR=/student
EOF
fi

chmod 755 $SCRIPTDIR/wod.sh
source $SCRIPTDIR/wod.sh

cd $SCRIPTDIR/../ansible
SHORTNAME="`hostname -s`"
FULLNAME=`ansible-inventory -i inventory --list | jq -r '._meta.hostvars | to_entries[] | .key' | grep -E "^$SHORTNAME(\.|$)"`
if [ _"$FULLNAME" = _"" ]; then
        echo "This machine is not a $WODTYPE machine, defined in the ansible inventory so can't be installed"
        exit -1
fi
PBKDIR=`ansible-inventory -i inventory --list | jq -r "._meta.hostvars | to_entries[] | select(.key == \"$FULLNAME\") | .value.PBKDIR"`

WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
# Another way using ansible
#DISTRIB=`ansible -m gather_facts -i inventory $FULLNAME | perl -p -e "s/$FULLNAME \| SUCCESS => //" | jq -r ".ansible_facts | .ansible_distribution"`
#DVER=`ansible -m gather_facts -i inventory $FULLNAME | perl -p -e "s/$FULLNAME \| SUCCESS => //" | jq -r ".ansible_facts | .ansible_distribution_major_version"`
if ! command -v ansible-galaxy &> /dev/null
then
    echo "ansible-galaxy could not be found, please install ansible"
    exit -1
fi
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "ubuntu-20.04" ]; then
	# Older distributions require an older version of the collection to work.
	# See https://github.com/ansible-collections/community.general
	ansible-galaxy collection install --force-with-deps community.general:4.8.5
else
	ansible-galaxy collection install community.general
fi
ansible-galaxy collection install ansible.posix


SCRIPTREL=`echo $SCRIPT | perl -p -e "s|$WODBEDIR||"`
if [ -x $WODPRIVDIR/$SCRIPTREL ];
then
	echo "Executing additional private script $WODPRIVDIR/$SCRIPTREL"
	$WODPRIVDIR/$SCRIPTREL
fi

if [ $WODTYPE = "backend" ]; then
	ANSPLAYOPT="-e LDAPSETUP=0 -e APPMIN=0 -e APPMAX=0"
elif [ $WODTYPE = "server" ] || [ $WODTYPE = "frontend" ]; then
	ANSPLAYOPT="-e LDAPSETUP=0"
fi
# Automatic Installation script for the system 
ansible-playbook -i inventory --limit $PBKDIR $ANSPLAYOPT install_$WODTYPE.yml

if [ $WODTYPE = "server" ]; then
	cd $WODSRVDIR
	# Start the PostgreSQL DB
	docker-compose up -d
	# Start the backend server
	npm start &
	# Seed the DB
	npm run seed-data
	# Reset the DB
	npm run reset-data
elif [ $WODTYPE = "frontend" ]; then
	cd $WODFEDIR
	npm start &
fi

cd $SCRIPTDIR/../ansible
ANSPLAYOPT=""
if [ -f $WODPRIVDIR/ansible/install_$WODTYPE.yml ]; then
	ansible-playbook -i inventory $WODANSOPT --limit $PBKDIR $ANSPLAYOPT install_$WODTYPE.yml
fi

ansible-playbook -i inventory --limit $PBKDIR check_$WODTYPE.yml
# Manages private part if any
if [ -f $WODPRIVDIR/ansible/check_$WODTYPE.yml ]; then
	ansible-playbook -i inventory $WODANSOPT --limit $PBKDIR check_$WODTYPE.yml
fi
date
