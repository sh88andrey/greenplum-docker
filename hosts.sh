for host in `cat allhost`; do
  echo $host
  ssh $host cat /etc/hosts | grep $host >> hosts
done
sudo cp hosts /etc/hosts
for host in `cat allhost`; do
  echo $host
  sudo scp hosts $host:/etc/hosts
done
