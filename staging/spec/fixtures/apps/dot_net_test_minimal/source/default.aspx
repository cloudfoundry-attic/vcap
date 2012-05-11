<%@ Page Language="VB" %>

<script runat="server">
	Sub Page_Load(Sender As Object, E As EventArgs)
		HelloWorld.Text = "Hello World!"
	End Sub
</script>

<html>
	<head>
		<title>ASP.NET Hello World</title>
	</head>
	<body bgcolor="#FFFFFF">
		<p>
			<asp:label id="HelloWorld" runat="server" />
		</p>
	</body>
</html>
