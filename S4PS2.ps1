function runS4{
	Param([parameter(Position=0)] [int]$port)

	$pool = [runspacefactory]::CreateRunspacePool(1, 100) 
	$pool.Open()  
	$endpoint = new-object System.Net.IPEndPoint ([system.net.ipaddress]::any, $port)
	[System.Net.Sockets.TcpListener] $listener = new-object System.Net.Sockets.TcpListener $endpoint
	try{
		$listener.start()
		}catch{
			echo "socket busy"
			exit
		}
	while($true){
		
		[System.Net.Sockets.TcpClient] $client = $listener.AcceptTcpClient()
		[system.gc]::Collect()

		[powershell] $p=[powershell]::create()
		$p.runspacepool = $pool
		
		[scriptblock] $task={
		Param([System.Net.Sockets.TcpClient] $client)
		[System.Net.Sockets.TcpClient] $tcp_target
		[System.Net.Sockets.NetworkStream]$client_stream

		function use_4v{
			$cmd = $client_stream.ReadByte()
			Switch ($cmd){
			1  {
					$ports = New-Object byte[] 2
					$client_stream.Read($ports,0,2) | Out-Null
					$target_port =  $ports[0]*256 + $ports[1]
					if ($target_port -gt 0){
						if ($target_port -lt 65535){
							$ip = New-Object byte[] 4
							$client_stream.Read($ip,0,4) | Out-Null
							$ob = New-Object object[] 1
							$ob[0]=$ip
							$target_ip = New-Object ipaddress $ob
							$target_endpoint = New-Object System.Net.IPEndPoint($target_ip,$target_port)
							$client_id=@()
								for($i=0;$i -le 256;$i++){
								$id=$client_stream.ReadByte()
								if($id -ne 0){
									$client_id.Add($id)
									$id=$client_stream.ReadByte()	
								}else{
									break
									}
								}
								$client_stream.WriteByte(0)
								
								$tcp_target= New-Object System.Net.Sockets.TcpClient
								try{
									$tcp_target.Connect($target_endpoint)
								}catch{
									close 
									}
								if ($tcp_target.Connected){ 
									try{
									$client_stream.WriteByte(90)
									$trash = New-Object byte[] 6
									$client_stream.Write($trash,0,6)
									$client_stream.Flush()
									$target_stream = $tcp_target.GetStream()
									
									$buffer = New-Object byte[] 16384
									
									$tcp_target.NoDelay= $true
									$client.NoDelay=$true

										while($true){
											$res = $false
											if($client_stream.DataAvailable){
											$i = $client_stream.Read($buffer,0,$buffer.Length)
											$target_stream.Write($buffer,0,$i) | Out-Null
												$res = $true
												}
											if($target_stream.DataAvailable){
											$i = $target_stream.Read($buffer,0,$buffer.Length)
											$client_stream.Write($buffer,0,$i) | Out-Null
												$res = $true
												}
											if(!$res){
											[System.Threading.Thread]::Sleep(200)
											}else{
												[System.Threading.Thread]::Sleep(2)
											}
										}
									}catch{
										close
										}
								}
						}
					}
				}	
			2 {
				send_error
				}
			default {
					send_error
				}		
			}
		}

		function send_error{
			$client_stream.WriteByte(0)
			$client_stream.WriteByte(91)
			$trash = New-Object byte[] 6
			$client_stream.Write($trash,0,6)
			$lient_stream.Flush()
			close
		}
		function close{
			try{
				$client.Close()
			}catch{
				}
			try{
				if($tcp_target)
				{$tcp_target.Close()}
			}catch{
				}
		}	

		function run{
			[system.gc]::Collect()
			try{
			$client_stream = $client.GetStream()
			$ver = $client_stream.ReadByte()	
					if($ver -eq 4) {
					use_4v
					}else{
					send_error
					}
		}catch{
			close
			}
			[system.gc]::Collect()
		}
		$trach = run
		}
		$p =$p.AddScript($task,$true) 
		$trash=$p.AddArgument($client) 
		$trash=$p.BeginInvoke()
		}
}
runS4 1080
exit
