putchar(c)
{
	extrn syscall;
	syscall(4, 1, &c, 1);
}

char(s, n)
{
	return ((s[n / 4] >> (((n - 4) % 4) * 8)) & 255);
}

putstr(s)
{
	auto i;

	i = 0;
	while (char(s, i))
	{
		putchar(char(s, i));
		i++;
	}
}

printn(n,b)
{
	extrn putchar;
	auto a;
	if (a = n / b)
		printn(a,b);
	putchar(n % b + '0');
}

main(ac, av, envp)
{
	extrn syscall, putchar, putstr;
	auto n;

	putstr("Printing args (");
	printn(ac, 10);
	putstr(")\n");

	n = 0;

	while (n < ac)
	{
		putstr(av[n]);
		putchar('\n');
		n++;
	}
}
