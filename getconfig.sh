#!/bin/bash

####该脚本用于生成接口输出字典以及相关配置文件
####生成输出字典需要list.conf 配置输出列表，并在list文件里配置输出字段
####生成配置文件需要定义inout.conf，设置输入输出的数据类型与对应字典
####默认软总线为8200和8250

#配置文件路径/zctt/scss/etc/name
name=mtp

mkdir -p $name
mkdir -p $name/dict_out
mkdir -p $name/dict_in
create_out_dict()
{
firstNodeName=`echo $1|awk -F"." '{print $1}'`
type_id=$2
type_name=$firstNodeName
headstr="<?xml version=\"1.0\"?>"
headstr+="\n"
headstr+="<"${firstNodeName}_out" type-class=\"CDR\" type-id=\""$type_id"\" type-name=\""$type_name$"\" version=\"171227\">"
headstr+="\n"
headstr+="\t<record>"
echo -e $headstr>$name/dict_out/${firstNodeName}_out.xml
awk -F, 'BEGIN{id=0}NR==FNR{a[$1]=$2;b[$1]=$3}NR>FNR{printf("\t\t<field>\n\t\t\t<field-name>%s</field-name>\n\t\t\t<id>%s</id>\n\t\t\t<type>%s</type>\n\t\t\t<length>%s</length>\n\t\t</field>\n",$1,id,a[$1],b[$1]);id++}'  dict.txt $1>>$name/dict_out/${firstNodeName}_out.xml

echo -e "\t</record>">>$name/dict_out/${firstNodeName}_out.xml
echo -e "</${firstNodeName}_out>">>$name/dict_out/${firstNodeName}_out.xml
}
create_cust()
{
script=`grep "<field-name>" $name/dict_out/$out_dict|awk -F">" '{print $2}'|awk -F"<" '{printf("@.%s=$.%s;n_flag",$1,$1)}'`
cat scss_customize_template.xml >$name/${flag}
sed -i "s/@@script@@/${script}/g" $name/${flag}
sed -i 's/n_flag/\n/g' $name/${flag}
sed -i "s/@@intype@@/$in_type/g" $name/${flag}
sed -i "s/@@outtype@@/$out_type/g" $name/${flag}
sed -i "s/@@in_dict@@/$in_dict/g" $name/${flag}
sed -i "s/@@out_dict@@/$out_dict/g" $name/${flag}
sed -i "s/big_data/$name/g" $name/${flag}
}
#生成字段类型文件
fun1()
{
rm dict.tmp*
for dic_file in $name/dict_in/*xml
do
if [ -f $dic_file ]
then
sed -n '/<record>/,/<\/record>/p' $dic_file|sed  '1d;$d'|awk  'BEGIN{FS="\n";RS="<field>"}{for(i=1;i<=NF;i++)if($i~/<field-name>/)printf("%s",$i);for(i=1;i<=NF;i++)if($i~/<type>/)printf("%s",$i);for(i=1;i<=NF;i++)if($i~/<length>/)printf("%s",$i);printf("\n")}'|sed 's/<field-name>//g;s/<\/field-name>//g;s/<type>//g;s/<\/type>//g;s/<length>//g;s/<\/length>//g'|awk '$1!=""{printf("%s,%s,%s\n",$1,$2,$3)}' >>dict.tmp1
fi
done
if [ -f $dic_file ]
then
cat dict.tmp1 dict.txt >dict.tmp2
awk '!a[$0]++' dict.tmp2 >dict.txt
fi
}
fun2()
{
#生成输出字典
while
read i
do
firstNodeName=`echo $i|awk -F, '{print $1}'`
type_id=`echo $i|awk -F, '{print $2}'`
create_out_dict $firstNodeName $type_id
done<list.conf
}
#生成cust配置
fun3()
{
while
read i
do
flag=`echo $i|sed 's/_out.xml//g'|sed 's/\.xml//g'|sed 's/ddict-//g'|awk -F, '{printf("scss_customize_%s_%s_8200_%s_8250_%s.xml\n",$1,$3,$4,$2)}'`
out_dict=`echo $i|awk -F, '{print $1}'`
out_type=`echo $i|awk -F, '{print $2}'`
in_dict=`echo $i|awk -F, '{print $3}'`
in_type=`echo $i|awk -F, '{print $4}'`
echo $in_dict $out_dict
create_cust $out_dict $out_type $in_dict $in_type
done<inout.conf
}
#生成cust监控配置
fun4()
{
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" >$name/scss.xml
t=1
for i in `ls $name/scss_customize*xml`
do
pname=`echo $i|awk -F"/" '{print $2}'|awk -F"_" '{for(i=3;i<NF-4;i++)printf("%s_",$i)}'`
cfgname=`echo $i|awk -F"/" '{print $2}'`
echo "        <Application number=\"$t\" delay=\"2\" priority=\"10\">" >>$name/scss.xml
echo "		<path>/zctt/scss/bin/scss_customize -n $pname  -b -t -f file:///zctt/scss/etc/$name/$cfgname</path>" >>$name/scss.xml
echo "		</Application>" >>$name/scss.xml
done
echo "</root>">>$name/scss.xml
t=$((t+1))
}
#生成字段类型文件,输入输出字典已定义可不执行
#fun1
#生成输出字典,输入输出字典已定义可不执行
#fun2
#生成cust配置
fun3
#生成cust监控配置
fun4
