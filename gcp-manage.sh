#!/bin/bash
set -e

# Configuration
INSTANCE_NAME="gcp-dev-box"
ZONE="us-west4-a"

# Function to display usage
usage() {
    echo "Usage: $0 {status|logs|restart|ssh|connect|stop|start|delete|serial}"
    echo ""
    echo "Commands:"
    echo "  status    - Show instance and container status"
    echo "  logs      - View container logs"
    echo "  restart   - Restart the container"
    echo "  ssh       - SSH into the VM host"
    echo "  connect   - SSH into the running container"
    echo "  stop      - Stop the instance"
    echo "  start     - Start the instance"
    echo "  delete    - Delete the instance"
    echo "  serial    - View serial port output (useful for debugging boot issues)"
    exit 1
}

# Check if command provided
if [ $# -eq 0 ]; then
    usage
fi

COMMAND=$1

case $COMMAND in
    status)
        echo "=== Instance Status ==="
        gcloud compute instances describe "$INSTANCE_NAME" \
            --zone="$ZONE" \
            --format="table(name,status,networkInterfaces[0].accessConfigs[0].natIP)" || echo "Instance not found"

        echo ""
        echo "=== Container Status ==="
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" \
            --command="docker ps -a --filter name=dev-container" || echo "Cannot connect to instance"
        ;;

    logs)
        echo "Fetching container logs..."
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" \
            --command="docker logs dev-container -f"
        ;;

    restart)
        echo "Restarting container..."
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" \
            --command="sudo systemctl restart dev-container.service"
        echo "Container restarted. Use '$0 logs' to view logs."
        ;;

    ssh)
        echo "Connecting to VM host..."
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE"
        ;;

    connect)
        echo "Connecting to container..."
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" \
            --command="docker exec -it dev-container /bin/bash"
        ;;

    stop)
        echo "Stopping instance..."
        gcloud compute instances stop "$INSTANCE_NAME" --zone="$ZONE"
        ;;

    start)
        echo "Starting instance..."
        gcloud compute instances start "$INSTANCE_NAME" --zone="$ZONE"
        ;;

    delete)
        echo "WARNING: This will permanently delete the instance!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            gcloud compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --quiet
            echo "Instance deleted."
        else
            echo "Cancelled."
        fi
        ;;

    serial)
        echo "Fetching serial port output..."
        gcloud compute instances get-serial-port-output "$INSTANCE_NAME" --zone="$ZONE"
        ;;

    *)
        echo "Unknown command: $COMMAND"
        usage
        ;;
esac
